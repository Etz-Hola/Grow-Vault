const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("GrowVault System Tests", function () {
  let growVault, factory, usdt;
  let owner, user1, developer;
  const DURATION = 30 * 24 * 60 * 60; // 30 days in seconds
  const PURPOSE = "Test Savings";
  const SALT = ethers.utils.formatBytes32String("testSalt");

  beforeEach(async function () {
    [owner, user1, developer] = await ethers.getSigners();

    // Deploy Mock ERC20 token (simulating USDT)
    const MockERC20 = await ethers.getContractFactory("MockERC20");
    usdt = await MockERC20.deploy("Mock USDT", "USDT", ethers.utils.parseUnits("1000000", "6"));
    await usdt.deployed();

    // Deploy Factory
    const GrowVaultFactory = await ethers.getContractFactory("GrowVaultFactory");
    factory = await GrowVaultFactory.deploy(developer.address);
    await factory.deployed();

    // Create a vault
    const tx = await factory.createVault(PURPOSE, DURATION, SALT);
    const receipt = await tx.wait();
    const vaultAddress = receipt.events[0].args.vault;
    growVault = await ethers.getContractAt("GrowVault", vaultAddress);

    // Mint some tokens to user1 and approve vault
    await usdt.transfer(user1.address, ethers.utils.parseUnits("1000", "6"));
    await usdt.connect(user1).approve(growVault.address, ethers.constants.MaxUint256);
  });

  describe("Factory Tests", function () {
    it("should create a vault with correct parameters", async function () {
      expect(await growVault.owner()).to.equal(owner.address);
      expect(await growVault.savingPurpose()).to.equal(PURPOSE);
      expect(await growVault.savingDuration()).to.equal(DURATION);
      expect(await growVault.developer()).to.equal(developer.address);
      expect(await growVault.startTime()).to.be.above(0);
    });

    it("should store vault address in array", async function () {
      const vaults = await factory.getVaults();
      expect(vaults).to.include(growVault.address);
    });

    it("should predict correct vault address", async function () {
      const predictedAddress = await factory.predictVaultAddress(PURPOSE, DURATION, SALT);
      expect(predictedAddress).to.equal(growVault.address);
    });
  });

  describe("GrowVault Tests", function () {
    it("should allow deposits of supported tokens", async function () {
      const depositAmount = ethers.utils.parseUnits("100", "6");
      await expect(growVault.connect(user1).deposit(usdt.address, depositAmount))
        .to.emit(growVault, "Deposited")
        .withArgs(usdt.address, depositAmount);
      expect(await growVault.getBalance(usdt.address)).to.equal(depositAmount);
    });

    it("should allow withdrawal after duration", async function () {
      const depositAmount = ethers.utils.parseUnits("100", "6");
      await growVault.connect(user1).deposit(usdt.address, depositAmount);

      await ethers.provider.send("evm_increaseTime", [DURATION + 1]);
      await ethers.provider.send("evm_mine");

      await expect(growVault.withdraw(usdt.address))
        .to.emit(growVault, "Withdrawn")
        .withArgs(usdt.address, depositAmount, false);
      expect(await usdt.balanceOf(owner.address)).to.equal(depositAmount);
    });

    it("should apply penalty for early withdrawal", async function () {
      const depositAmount = ethers.utils.parseUnits("100", "6");
      await growVault.connect(user1).deposit(usdt.address, depositAmount);

      const ownerBalanceBefore = await usdt.balanceOf(owner.address);
      const devBalanceBefore = await usdt.balanceOf(developer.address);

      await growVault.withdraw(usdt.address);

      const ownerBalanceAfter = await usdt.balanceOf(owner.address);
      const devBalanceAfter = await usdt.balanceOf(developer.address);

      const penalty = depositAmount.mul(15).div(100);
      const ownerAmount = depositAmount.sub(penalty);

      expect(ownerBalanceAfter.sub(ownerBalanceBefore)).to.equal(ownerAmount);
      expect(devBalanceAfter.sub(devBalanceBefore)).to.equal(penalty);
    });
  });
});
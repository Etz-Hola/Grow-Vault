import { ethers } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with account:", deployer.address);

  // Deploy GrowVaultFactory
  const developerAddress = deployer.address; // For simplicity, using deployer as developer
  const GrowVaultFactory = await ethers.getContractFactory("GrowVaultFactory");
  const factory = await GrowVaultFactory.deploy(developerAddress);
  await factory.deployed();
  console.log("GrowVaultFactory deployed to:", factory.address);

  // Create a new GrowVault using CREATE2
  const savingPurpose = "Buy a new laptop";
  const duration = 30 * 24 * 60 * 60; // 30 days in seconds
  const salt = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("unique-salt-1"));

  const tx = await factory.createVault(savingPurpose, duration, salt);
  const receipt = await tx.wait();
  const vaultAddress = receipt.events?.[0]?.args?.vault; // Extract vault address from event
  console.log("New GrowVault deployed to:", vaultAddress);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
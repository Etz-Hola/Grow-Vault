// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./GrowVault.sol";

contract GrowVaultFactory {
    address[] public vaults;  // Array of created vault addresses
    address public developer; // Developer address for penalty fees

    event VaultCreated(address indexed vault, string purpose);

    constructor(address _developer) {
        developer = _developer;
    }

    // Create a new vault using CREATE2
    function createVault(
        string memory _savingPurpose,
        uint256 _duration,
        bytes32 _salt
    ) public returns (address) {
        address newVault = address(
            new GrowVault{salt: _salt}(_savingPurpose, _duration, developer)
        );
        vaults.push(newVault);
        emit VaultCreated(newVault, _savingPurpose);
        return newVault;
    }

    // Alternative: Create a vault using CREATE (new keyword)
    function createVaultWithNew(
        string memory _savingPurpose,
        uint256 _duration
    ) public returns (address) {
        GrowVault newVault = new GrowVault(_savingPurpose, _duration, developer);
        vaults.push(address(newVault));
        emit VaultCreated(address(newVault), _savingPurpose);
        return address(newVault);
    }

    // Get the list of all vaults
    function getVaults() public view returns (address[] memory) {
        return vaults;
    }

    // Predict the address of a vault using CREATE2
    function predictVaultAddress(
        string memory _savingPurpose,
        uint256 _duration,
        bytes32 _salt
    ) public view returns (address) {
        bytes memory bytecode = abi.encodePacked(
            type(GrowVault).creationCode,
            abi.encode(_savingPurpose, _duration, developer)
        );
        bytes32 hash = keccak256(
            abi.encodePacked(bytes1(0xff), address(this), _salt, keccak256(bytecode))
        );
        return address(uint160(uint256(hash)));
    }
}
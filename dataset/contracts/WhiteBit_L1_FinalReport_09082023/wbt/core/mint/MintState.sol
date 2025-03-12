// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

contract MintState {
    address public owner;
    uint256 public mintLimit;

    event Mint(uint256 amount, bytes32 burnTxHash, uint8 burnTxNetwork);

    modifier onlyOwner {
        require(msg.sender == owner, "Available only for owner");
        _;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero address is not a valid owner");
        owner = newOwner;
    }

    function changeMintLimit(uint256 newLimit) external onlyOwner {
        require(newLimit < mintLimit, "Mint limit cannot be increased");
        mintLimit = newLimit;
    }
}

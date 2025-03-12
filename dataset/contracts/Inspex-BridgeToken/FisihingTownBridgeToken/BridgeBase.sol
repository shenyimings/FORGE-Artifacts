// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IERC20.sol";

contract BridgeBase is Ownable {
    event TransferTokenToOnchain(
        address indexed sender,
        uint256 indexed nonce,
        address indexed to,
        uint256 amount
    );
    event TransferTokenToOffchain(
        address indexed sender,
        uint256 indexed nonce,
        uint256 amount
    );

    IERC20 public token;
    mapping(uint256 => bool) public offchainNonces;
    uint256 public nonce;

    constructor(address _token) {
        require(_token != address(0), "token address cannot be zero");

        token = IERC20(_token);
    }

    function transferTokenToOnchain(
        uint256 offchainNonce,
        address to,
        uint256 amount
    ) external onlyOwner {
        require(offchainNonces[offchainNonce] == false, "nonce already used");
        offchainNonces[offchainNonce] = true;
        token.mint(to, amount);

        emit TransferTokenToOnchain(msg.sender, offchainNonce, to, amount);
    }

    function transferTokenToOffchain(uint256 amount) external {
        token.burnFrom(msg.sender, amount);
        nonce++;

        emit TransferTokenToOffchain(msg.sender, nonce, amount);
    }
}

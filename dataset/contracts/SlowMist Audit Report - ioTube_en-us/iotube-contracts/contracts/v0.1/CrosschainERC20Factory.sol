// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./CrosschainERC20.sol";

contract CrosschainERC20Factory is Ownable {
    event NewCrosschainERC20(
        address indexed token,
        address indexed coToken,
        address lord,
        string name,
        string symbol,
        uint8 decimals
    );
    address public lord;

    constructor(address _lord) {
        lord = _lord;
    }

    function createForeignToken(
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    ) public onlyOwner returns (CrosschainERC20) {
        CrosschainERC20 cc = new CrosschainERC20(ERC20(address(0)), lord, _name, _symbol, _decimals);
        emit NewCrosschainERC20(address(cc), address(0), lord, _name, _symbol, _decimals);

        return cc;
    }

    function createLocalToken(
        ERC20 _coToken,
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    ) public onlyOwner returns (CrosschainERC20) {
        require(address(_coToken) != address(0), "invalid paramter");
        CrosschainERC20 cc = new CrosschainERC20(_coToken, lord, _name, _symbol, _decimals);
        emit NewCrosschainERC20(address(cc), address(_coToken), lord, _name, _symbol, _decimals);
        return cc;
    }
}

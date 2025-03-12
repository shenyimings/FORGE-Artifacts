// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC20/ERC20.sol)

pragma solidity 0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";

import "./Interface/IDeepToken.sol";

/**
 * @title DKeeper Escrow contract
 */
contract DKeeperEscrow {
    IDeepToken public deepToken;
    address public dKeeper;

    constructor(address deepToken_, address dKeeper_) {
        require(deepToken_ != address(0), "Invalid token address");
        require(dKeeper_ != address(0), "Invalid DKeeper address");

        deepToken = IDeepToken(deepToken_);
        dKeeper = dKeeper_;
    }

    function mint(address _account, uint256 _amount) external {
        require(msg.sender == dKeeper, "msg.sender should be same with DKeeper address");
        deepToken.mint(_account, _amount);
    }
}

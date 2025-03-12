// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@amxx/hre/contracts/tokens/utils/Checkpoints.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../finance/staking/Escrow.sol";
import "./P00lsTokenBase.sol";
import "./interfaces.sol";

/// @custom:security-contact security@p00ls.com
contract P00lsTokenXCreator is IEscrowReceiver, P00lsTokenBase
{
    using Checkpoints for Checkpoints.History;

    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    Escrow              public immutable stakingEscrow;
    IP00lsTokenCreator  public           creatorToken;
    Checkpoints.History internal         conversion;

    modifier onlyOwner() {
        require(owner() == msg.sender, "P00lsTokenXCreator: owner restricted");
        _;
    }

    modifier onlyParent() {
        require(address(creatorToken) == msg.sender, "P00lsTokenXCreator: creator token restricted");
        _;
    }

    modifier accrue() {
        stakingEscrow.release(creatorToken);
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address escrow)
        initializer()
    {
        stakingEscrow = Escrow(escrow);
    }

    function initialize(string calldata name, string calldata symbol, address parent)
        external
        initializer()
    {
        __ERC20_init(name, symbol);
        __ERC20Permit_init(name);
        creatorToken = IP00lsTokenCreator(parent);

        // before escrow release, ratio is 1:1
        conversion.push(1 ether);
    }

    function owner()
        public
        view
        override
        returns (address)
    {
        return creatorToken.owner();
    }

    /**
     * Deposit / withdraw
     */
    function onEscrowRelease(uint256)
        public
    {
        uint256 value = sharesToValue(1 ether);
        if (value != conversion.latest())
        {
            conversion.push(value);
        }
    }

    function deposit(uint256 value)
        public
    {
        depositFor(value, msg.sender);
    }

    function withdraw(uint256 shares)
        public
    {
        withdrawTo(shares, msg.sender);
    }

    function depositFor(uint256 value, address receiver)
        public
        accrue()
    {
        uint256 shares = valueToShares(value);

        SafeERC20.safeTransferFrom(IERC20(creatorToken), msg.sender, address(this), value);
        _mint(receiver, shares);

        onEscrowRelease(0);
    }

    function withdrawTo(uint256 shares, address receiver)
        public
        accrue()
    {
        uint256 value  = sharesToValue(shares);

        _burn(msg.sender, shares);
        SafeERC20.safeTransfer(IERC20(creatorToken), receiver, value);

        onEscrowRelease(0);
    }

    function valueToShares(uint256 value)
        public
        view
        returns (uint256)
    {
        uint256 supply  = totalSupply();
        uint256 balance = IERC20(creatorToken).balanceOf(address(this));
        return balance > 0 && supply > 0 ? Math.mulDiv(value, supply, balance) : value;
    }

    function sharesToValue(uint256 shares)
        public
        view
        returns (uint256)
    {
        uint256 supply  = totalSupply();
        uint256 balance = IERC20(creatorToken).balanceOf(address(this));
        return balance > 0 && supply > 0 ? Math.mulDiv(shares, balance, supply) : supply;
    }

    function pastSharesToValue(uint256 shares, uint256 blockNumber)
        public
        view
        returns (uint256)
    {
        return Math.mulDiv(shares, conversion.past(blockNumber), 1 ether);
    }

    /**
     * Delegation
     */
    function __delegate(address delegator, address delegatee)
        external
        onlyParent()
    {
        _delegate(delegator, delegatee);
    }

    function delegate(address)
        public
        pure
        override
    {
        revert("P00lsTokenXCreator: delegation is registered on the creatorToken");
    }

    function delegateBySig(address, uint256, uint256, uint8, bytes32, bytes32)
        public
        pure
        override
    {
        revert("P00lsTokenXCreator: delegation is registered on the creatorToken");
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "../../utils/Timers.sol";
import "../ModuleBase.sol";

contract BuyoutModule is IModule, ModuleBase, Timers
{
    string public constant override name = type(BuyoutModule).name;

    // bytes32 public constant BUYOUT_DURATION = bytes32(uint256(keccak256("BUYOUT_DURATION")) - 1);
    bytes32 public constant BUYOUT_DURATION = 0x2b0302f2fecc31c4abdae5dbfeb4ffb88f5e75f2102ec01dda9073a9330d6b1c;
    // bytes32 public constant BUYOUT_AUTH_RATIO = bytes32(uint256(keccak256("BUYOUT_AUTH_RATIO")) - 1);
    bytes32 public constant BUYOUT_AUTH_RATIO = 0xfe28b1c1d768c9fc13cde756c61b63ec3a40333a8bb3cd2e556327781fbea03c;

    mapping(ShardedWallet => address) internal _proposers;
    mapping(ShardedWallet => uint256) internal _prices;
    mapping(ShardedWallet => uint256) public _deposit;

    event BuyoutOpened(ShardedWallet indexed wallet, address proposer, uint256 pricePerShard);
    event BuyoutClosed(ShardedWallet indexed wallet, address closer);
    event BuyoutClaimed(ShardedWallet indexed wallet, address user);
    event BuyoutFinalized(ShardedWallet indexed wallet);

    modifier buyoutAuthorized(ShardedWallet wallet, address user)
    {
        require(wallet.balanceOf(user) >= Math.max(
            wallet.totalSupply() * wallet.governance().getConfig(address(wallet), BUYOUT_AUTH_RATIO) / 10**18,
            1
        ));
        _;
    }

    function openBuyout(ShardedWallet wallet, uint256 pricePerShard)
    external payable buyoutAuthorized(wallet, msg.sender) onlyBeforeTimer(bytes32(uint256(uint160(address(wallet)))))
    {
        uint256 ownedshards = wallet.balanceOf(msg.sender);
        uint256 buyoutprice = (wallet.totalSupply() - ownedshards) * pricePerShard / 10**18;

        Timers._startTimer(bytes32(uint256(uint160(address(wallet)))), wallet.governance().getConfig(address(wallet), BUYOUT_DURATION));
        _proposers[wallet] = msg.sender;
        _prices[wallet]    = pricePerShard;
        _deposit[wallet]   = buyoutprice;

        wallet.moduleTransferOwnership(address(this));
        wallet.moduleTransfer(msg.sender, address(this), ownedshards);
        Address.sendValue(payable(msg.sender), msg.value - buyoutprice);

        emit BuyoutOpened(wallet, msg.sender, pricePerShard);
    }

    function closeBuyout(ShardedWallet wallet)
    external payable onlyDuringTimer(bytes32(uint256(uint160(address(wallet)))))
    {
        uint256 pricePerShard = _prices[wallet];
        uint256 lockedShards  = wallet.balanceOf(address(this));
        uint256 buyShards     = Math.min(msg.value * 10**18 / pricePerShard, lockedShards);
        uint256 buyprice      = buyShards * pricePerShard / 10**18;
        _deposit[wallet]     += buyprice;

        // do the transfer (update lockedShards in case of reentrancy attempt)
        wallet.transfer(msg.sender, buyShards);

        // do the close of all locked shards have been bought
        if (buyShards == lockedShards)
        {
            // stop buyout timer & reset wallet ownership
            Timers._stopTimer(bytes32(uint256(uint160(address(wallet)))));
            wallet.renounceOwnership();

            // transfer funds to proposer
            address proposer = _proposers[wallet];
            uint256 deposit  = _deposit[wallet];
            delete _proposers[wallet];
            delete _prices[wallet];
            delete _deposit[wallet];
            Address.sendValue(payable(proposer), deposit);

            // emit event
            emit BuyoutClosed(wallet, msg.sender);
        }

        // refund extra value
        Address.sendValue(payable(msg.sender), msg.value - buyprice);
    }

    function claimBuyout(ShardedWallet wallet)
    external onlyAfterTimer(bytes32(uint256(uint160(address(wallet)))))
    {
        uint256 pricePerShard = _prices[wallet];
        uint256 shards        = wallet.balanceOf(msg.sender);
        uint256 value         = shards * pricePerShard / 10**18;

        wallet.moduleBurn(msg.sender, shards);
        Address.sendValue(payable(msg.sender), value);

        emit BuyoutClaimed(wallet, msg.sender);
    }

    function claimBuyoutBackup(ShardedWallet wallet)
    external onlyAfterTimer(bytes32(uint256(uint160(address(wallet)))))
    {
        uint256 pricePerShard = _prices[wallet];
        uint256 shards        = wallet.balanceOf(msg.sender);
        uint256 value         = shards * pricePerShard / 10**18;

        wallet.burnFrom(msg.sender, shards);
        Address.sendValue(payable(msg.sender), value);

        emit BuyoutClaimed(wallet, msg.sender);
    }

    function finalizeBuyout(ShardedWallet wallet)
    external onlyAfterTimer(bytes32(uint256(uint160(address(wallet)))))
    {
        // Warning: do NOT burn the locked shards, this would allow the last holder to retrieve ownership of the wallet
        require(_proposers[wallet] != address(0));
        wallet.transferOwnership(_proposers[wallet]);
        delete _proposers[wallet];
        delete _deposit[wallet];

        emit BuyoutFinalized(wallet);
    }
}

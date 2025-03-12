// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
pragma abicoder v2;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "../../utils/Timers.sol";
import "../ModuleBase.sol";

contract ActionModule is IModule, ModuleBase, Timers
{
    string public constant override name = type(ActionModule).name;

    // bytes32 public constant ACTION_DURATION = bytes32(uint256(keccak256("ACTION_DURATION")) - 1);
    bytes32 public constant ACTION_DURATION = 0x05f91198c37cc2578c2915e1614db3bf5c90e3387bd106bdfbb0da82514418dd;
    // bytes32 public constant ACTION_AUTH_RATIO = bytes32(uint256(keccak256("ACTION_AUTH_RATIO")) - 1);
    bytes32 public constant ACTION_AUTH_RATIO = 0x3c3813978ff64b4dbcec0d1ea3c72ec1393a708e0a785f2797bac1f61c3d7e09;

    event ActionScheduled(ShardedWallet indexed wallet, bytes32 indexed uid, bytes32 indexed id, uint256 i, address to, uint256 value, bytes data);
    event ActionExecuted(ShardedWallet indexed wallet, bytes32 indexed uid, bytes32 indexed id, uint256 i, address to, uint256 value, bytes data);
    event ActionCancelled(ShardedWallet indexed wallet, bytes32 indexed uid, bytes32 indexed id);

    modifier actionAuthorized(ShardedWallet wallet, address user)
    {
        require(wallet.balanceOf(user) >= Math.max(
            wallet.totalSupply() * wallet.governance().getConfig(address(wallet), ACTION_AUTH_RATIO) / 10**18,
            1
        ));
        _;
    }

    function schedule(ShardedWallet wallet, address[] memory to, uint256[] memory value, bytes[] memory data)
    public actionAuthorized(wallet, msg.sender) returns (bytes32)
    {
        require(to.length == value.length);
        require(to.length == data.length);
        bytes32 id  = keccak256(abi.encode(to, value, data));
        bytes32 uid = keccak256(abi.encode(wallet, id));

        Timers._startTimer(uid, wallet.governance().getConfig(address(wallet), ACTION_DURATION));

        for (uint256 i = 0; i < to.length; ++i) {
            emit ActionScheduled(wallet, uid, id, i, to[i], value[i], data[i]);
        }

        return id;
    }

    function execute(ShardedWallet wallet, address[] memory to, uint256[] memory value, bytes[] memory data)
    public actionAuthorized(wallet, msg.sender) returns (bool)
    {
        require(wallet.owner() == address(0)); // buyout takes over ownership
        require(to.length == value.length);
        require(to.length == data.length);
        bytes32 id  = keccak256(abi.encode(to, value, data));
        bytes32 uid = keccak256(abi.encode(wallet, id));

        Timers._resetTimer(uid);

        for (uint256 i = 0; i < to.length; ++i) {
            wallet.moduleExecute(to[i], value[i], data[i]);
            emit ActionExecuted(wallet, uid, id, i, to[i], value[i], data[i]);
        }

        return true;
    }

    function cancel(ShardedWallet wallet, bytes32 id)
    public actionAuthorized(wallet, msg.sender) returns (bool)
    {
        bytes32 uid = keccak256(abi.encode(wallet, id));

        Timers._stopTimer(uid);

        emit ActionCancelled(wallet, uid, id);

        return true;
    }
}

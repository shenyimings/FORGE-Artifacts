// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "../wallet/ShardedWallet.sol";
import "./IGovernance.sol";

contract Governance is IGovernance, AccessControlEnumerable
{
    // bytes32 public constant MODULE_ROLE         = bytes32(uint256(keccak256("MODULE_ROLE")) - 1);
    bytes32 public constant MODULE_ROLE         = 0x5098275140f5753db46c42f6e139939968848633a1298402189fdfdafa69b452;
    // bytes32 public constant AUTHORIZATION_RATIO = bytes32(uint256(keccak256("AUTHORIZATION_RATIO")) - 1);
    bytes32 public constant AUTHORIZATION_RATIO = 0x9f280153bc61a10b7af5e9374ead4471b587c3bdcab2b4ab6bdd38136e8544a1;
    address public constant GLOBAL_CONFIG       = address(0);

    mapping(address => mapping(bytes32 => uint256)) internal _config;
    mapping(address => mapping(address => bool   )) internal _disabled;
    mapping(address => mapping(bytes4  => address)) internal _staticcalls;
    mapping(bytes32 => bool) internal _globalOnlyKeys;

    event ModuleDisabled(address wallet, address indexed module, bool disabled);
    event ModuleSet(bytes4 indexed sig, address indexed value, address indexed wallet);
    event GlobalModuleSet(bytes4 indexed sig, address indexed value);
    event ConfigSet(bytes32 indexed key, uint256 indexed value, address indexed wallet);
    event GlobalConfigSet(bytes32 indexed key, uint256 indexed value);
    event GlobalKeySet(bytes32 indexed key, bool indexed value);

    function initialize()
    public
    {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function isModule(address wallet, address module)
    public view override returns (bool)
    {
        return hasRole(MODULE_ROLE, module) && !_disabled[wallet][module];
    }

    function disableModuleForWallet(address wallet, address module, bool disabled)
    public
    {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender));
        _disabled[wallet][module] = disabled;
        emit ModuleDisabled(wallet, module, disabled);
    }

    function isAuthorized(address wallet, address user)
    public view override returns (bool)
    {
        return ShardedWallet(payable(wallet)).balanceOf(user) >= Math.max(
            ShardedWallet(payable(wallet)).totalSupply() * getConfig(wallet, AUTHORIZATION_RATIO) / 10**18,
            1
        );
    }

    function getModule(address wallet, bytes4 sig)
    public view override returns (address)
    {
        address global = _staticcalls[GLOBAL_CONFIG][sig];
        address local  = _staticcalls[wallet][sig];
        return _globalOnlyKeys[bytes32(sig)] || local == address(0) ? global : local;
    }

    function setModule(bytes4 sig, address value)
    public
    {
        _staticcalls[msg.sender][sig] = value;
        emit ModuleSet(sig, value, msg.sender);
    }

    function setGlobalModule(bytes4 sig, address value)
    public
    {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender));
        _staticcalls[GLOBAL_CONFIG][sig] = value;
        emit GlobalModuleSet(sig, value);
    }

    function getConfig(address wallet, bytes32 key)
    public view override returns (uint256)
    {
        uint256 global = _config[GLOBAL_CONFIG][key];
        uint256 local  = _config[wallet][key];
        return _globalOnlyKeys[key] || local == 0 ? global : local;
    }

    function setConfig(bytes32 key, uint256 value)
    public
    {
        _config[msg.sender][key] = value;
        emit ConfigSet(key, value, msg.sender);
    }

    function setGlobalConfig(bytes32 key, uint256 value)
    public
    {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender));
        _config[GLOBAL_CONFIG][key] = value;
        emit GlobalConfigSet(key, value);
    }

    function getGlobalOnlyKey(bytes32 key)
    public view returns (bool)
    {
        return _globalOnlyKeys[key];
    }

    function setGlobalKey(bytes32 key, bool value)
    public
    {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender));
        _globalOnlyKeys[key] = value;
        emit GlobalKeySet(key, value);
    }

    function getNiftexWallet() public view override returns(address) {
        return getRoleMember(DEFAULT_ADMIN_ROLE, 0);
    }
}

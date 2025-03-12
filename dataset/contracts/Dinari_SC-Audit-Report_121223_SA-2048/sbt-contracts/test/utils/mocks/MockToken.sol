// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

// import "solady/src/tokens/ERC20.sol";
import {MockERC20PermitVersion} from "./MockERC20PermitVersion.sol";
import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";

contract MockToken is MockERC20PermitVersion, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    string _name;
    string _symbol;

    mapping(address => bool) public isBlacklisted;
    mapping(address => bool) public isBlackListed;
    mapping(address => bool) public isBlocked;

    constructor(string memory name_, string memory symbol_)
        MockERC20PermitVersion(
            name_,
            Strings.toString(uint8(uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao))) % 250))
        )
        ERC20(name_, symbol_)
    {
        _name = name_;
        _symbol = symbol_;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
    }

    function name() public view override returns (string memory) {
        return _name;
    }

    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function mint(address account, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(account, amount);
    }

    function blacklist(address account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        isBlacklisted[account] = true;
        isBlackListed[account] = true;
        isBlocked[account] = true;
    }
}

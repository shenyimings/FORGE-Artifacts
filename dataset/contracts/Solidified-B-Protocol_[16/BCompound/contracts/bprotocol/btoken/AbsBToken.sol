pragma solidity 0.5.16;

// Interface
import { IRegistry } from "../interfaces/IRegistry.sol";
import { IAvatar } from "../interfaces/IAvatar.sol";
import { ICToken } from "../interfaces/CTokenInterfaces.sol";

// Libs
import { Exponential } from "../lib/Exponential.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

/**
 * @title AbsBToken is BProtocol token contract which represents the Compound's CToken
 */
contract AbsBToken is Exponential {
    using SafeERC20 for IERC20;

    // BProtocol Registry contract
    IRegistry public registry;
    // Compound's CToken this BToken contract is tied to
    address public cToken;

    modifier onlyPool() {
        require(msg.sender == registry.pool(), "BToken: only-pool-is-authorized");
        _;
    }

    modifier onlyDelegatee(address _avatar) {
        // `msg.sender` is delegatee
        require(registry.delegate(_avatar, msg.sender), "BToken: delegatee-not-authorized");
        _;
    }

    constructor(address _registry, address _cToken) internal {
        registry = IRegistry(_registry);
        cToken = _cToken;
    }

    function _myAvatar() internal returns (address) {
        return registry.getAvatar(msg.sender);
    }

    // CEther / CErc20
    // ===============
    function borrowBalanceCurrent(address account) external returns (uint256) {
        address _avatar = registry.getAvatar(account);
        return IAvatar(_avatar).borrowBalanceCurrent(cToken);
    }

    // redeem()
    function redeem(uint256 redeemTokens) external returns (uint256) {
        return _redeem(_myAvatar(), redeemTokens);
    }

    function redeemOnAvatar(address _avatar, uint256 redeemTokens) external onlyDelegatee(_avatar) returns (uint256) {
        return _redeem(_avatar, redeemTokens);
    }

    function _redeem(address _avatar, uint256 redeemTokens) internal returns (uint256) {
        uint256 result = IAvatar(_avatar).redeem(cToken, redeemTokens, msg.sender);
        require(result == 0, "BToken: redeem-failed");
        return result;
    }

    // redeemUnderlying()
    function redeemUnderlying(uint256 redeemAmount) external returns (uint256) {
        return _redeemUnderlying(_myAvatar(), redeemAmount);
    }

    function redeemUnderlyingOnAvatar(address _avatar, uint256 redeemAmount) external onlyDelegatee(_avatar) returns (uint256) {
        return _redeemUnderlying(_avatar, redeemAmount);
    }

    function _redeemUnderlying(address _avatar, uint256 redeemAmount) internal returns (uint256) {
        uint256 result = IAvatar(_avatar).redeemUnderlying(cToken, redeemAmount, msg.sender);
        require(result == 0, "BToken: redeemUnderlying-failed");
        return result;
    }

    // borrow()
    function borrow(uint256 borrowAmount) external returns (uint256) {
        return _borrow(_myAvatar(), borrowAmount);
    }

    function borrowOnAvatar(address _avatar, uint256 borrowAmount) external onlyDelegatee(_avatar) returns (uint256) {
        return _borrow(_avatar, borrowAmount);
    }

    function _borrow(address _avatar, uint256 borrowAmount) internal returns (uint256) {
        uint256 result = IAvatar(_avatar).borrow(cToken, borrowAmount, msg.sender);
        require(result == 0, "BToken: borrow-failed");
        return result;
    }

    // other functions
    function exchangeRateCurrent() public returns (uint256) {
        return ICToken(cToken).exchangeRateCurrent();
    }

    function exchangeRateStored() public view returns (uint) {
        return ICToken(cToken).exchangeRateStored();
    }

    // IERC20
    // =======
    // transfer()
    function transfer(address dst, uint256 amount) external returns (bool) {
        return _transfer(_myAvatar(), dst, amount);
    }

    function transferOnAvatar(address _avatar, address dst, uint256 amount) external onlyDelegatee(_avatar) returns (bool) {
        return _transfer(_avatar, dst, amount);
    }

    function _transfer(address _avatar, address dst, uint256 amount) internal returns (bool) {
        bool result = IAvatar(_avatar).transfer(cToken, dst, amount);
        require(result, "BToken: transfer-failed");
        return result;
    }

    // transferFrom()
    function transferFrom(address src, address dst, uint256 amount) external returns (bool) {
        return _transferFrom(_myAvatar(), src, dst, amount);
    }

    function transferFromOnAvatar(address _avatar, address src, address dst, uint256 amount) external onlyDelegatee(_avatar) returns (bool) {
        return _transferFrom(_avatar, src, dst, amount);
    }

    function _transferFrom(address _avatar, address src, address dst, uint256 amount) internal returns (bool) {
        bool result = IAvatar(_avatar).transferFrom(cToken, src, dst, amount);
        require(result, "BToken: transferFrom-failed");
        return result;
    }

    // approve()
    function approve(address spender, uint256 amount) public returns (bool) {
        return IAvatar(_myAvatar()).approve(cToken, spender, amount);
    }

    function approveOnAvatar(address _avatar, address spender, uint256 amount) public onlyDelegatee(_avatar) returns (bool) {
        return IAvatar(_avatar).approve(cToken, spender, amount);
    }

    function allowance(address owner, address spender) public view returns (uint256) {
        return ICToken(cToken).allowance(registry.avatarOf(owner), registry.avatarOf(spender));
    }

    function balanceOf(address owner) public view returns (uint256) {
        return ICToken(cToken).balanceOf(registry.avatarOf(owner));
    }

    function balanceOfUnderlying(address owner) external returns (uint) {
        return ICToken(cToken).balanceOfUnderlying(registry.avatarOf(owner));
    }

    function name() public view returns (string memory) {
        return ICToken(cToken).name();
    }

    function symbol() public view returns (string memory) {
        return ICToken(cToken).symbol();
    }

    function decimals() public view returns (uint8) {
        return ICToken(cToken).decimals();
    }

    function totalSupply() public view returns (uint256) {
        return ICToken(cToken).totalSupply();
    }
}
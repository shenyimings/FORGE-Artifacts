// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {IMorpho} from "src/interfaces/IMorpho.sol";
import {ERC4626UpgradeableSafe} from "@morpho-utils/ERC4626UpgradeableSafe.sol";
import {IPool} from "@aave-v3-core/interfaces/IPool.sol";

import {ERC20, SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";

contract UserMock {
    using SafeTransferLib for ERC20;

    IMorpho internal morpho;
    IPool internal pool;

    uint256 internal constant DEFAULT_MAX_ITERATIONS = 10;

    constructor(address _morpho) {
        morpho = IMorpho(_morpho);
        pool = IPool(morpho.pool());
    }

    receive() external payable {}

    function balanceOf(address token) external view returns (uint256) {
        return ERC20(token).balanceOf(address(this));
    }

    function approve(address token, uint256 amount) external {
        ERC20(token).safeApprove(address(morpho), amount);
    }

    function approve(address token, address spender, uint256 amount) external {
        ERC20(token).safeApprove(spender, amount);
    }

    function supply(address underlying, uint256 amount, address onBehalf, uint256 maxIterations)
        public
        returns (uint256)
    {
        return morpho.supply(underlying, amount, onBehalf, maxIterations);
    }

    function supply(address underlying, uint256 amount, address onBehalf) public returns (uint256) {
        return supply(underlying, amount, onBehalf, DEFAULT_MAX_ITERATIONS);
    }

    function supply(address underlying, uint256 amount, uint256 maxIterations) public returns (uint256) {
        return supply(underlying, amount, address(this), maxIterations);
    }

    function supply(address underlying, uint256 amount) public returns (uint256) {
        return supply(underlying, amount, address(this));
    }

    function supplyCollateral(address underlying, uint256 amount, address onBehalf) public returns (uint256) {
        return morpho.supplyCollateral(underlying, amount, onBehalf);
    }

    function supplyCollateral(address underlying, uint256 amount) public returns (uint256) {
        return supplyCollateral(underlying, amount, address(this));
    }

    function borrow(address underlying, uint256 amount, address onBehalf, address receiver, uint256 maxIterations)
        public
        returns (uint256)
    {
        return morpho.borrow(underlying, amount, onBehalf, receiver, maxIterations);
    }

    function borrow(address underlying, uint256 amount, address onBehalf, address receiver) public returns (uint256) {
        return borrow(underlying, amount, onBehalf, receiver, DEFAULT_MAX_ITERATIONS);
    }

    function borrow(address underlying, uint256 amount, address onBehalf, uint256 maxIterations)
        public
        returns (uint256)
    {
        return borrow(underlying, amount, onBehalf, address(this), maxIterations);
    }

    function borrow(address underlying, uint256 amount, address onBehalf) public returns (uint256) {
        return borrow(underlying, amount, onBehalf, address(this));
    }

    function borrow(address underlying, uint256 amount, uint256 maxIterations) public returns (uint256) {
        return borrow(underlying, amount, address(this), address(this), maxIterations);
    }

    function borrow(address underlying, uint256 amount) public returns (uint256) {
        return borrow(underlying, amount, address(this));
    }

    function repay(address underlying, uint256 amount, address onBehalf) public returns (uint256) {
        return morpho.repay(underlying, amount, onBehalf);
    }

    function repay(address underlying, uint256 amount) public returns (uint256) {
        return repay(underlying, amount, address(this));
    }

    function withdraw(address underlying, uint256 amount, address onBehalf, address receiver, uint256 maxIterations)
        public
        returns (uint256)
    {
        return morpho.withdraw(underlying, amount, onBehalf, receiver, maxIterations);
    }

    function withdraw(address underlying, uint256 amount, address onBehalf, address receiver)
        public
        returns (uint256)
    {
        return withdraw(underlying, amount, onBehalf, receiver, DEFAULT_MAX_ITERATIONS);
    }

    function withdraw(address underlying, uint256 amount, uint256 maxIterations) public returns (uint256) {
        return withdraw(underlying, amount, address(this), address(this), maxIterations);
    }

    function withdraw(address underlying, uint256 amount, address onBehalf) public returns (uint256) {
        return withdraw(underlying, amount, onBehalf, address(this));
    }

    function withdraw(address underlying, uint256 amount) public returns (uint256) {
        return withdraw(underlying, amount, address(this));
    }

    function withdrawCollateral(address underlying, uint256 amount, address onBehalf, address receiver)
        public
        returns (uint256)
    {
        return morpho.withdrawCollateral(underlying, amount, onBehalf, receiver);
    }

    function withdrawCollateral(address underlying, uint256 amount, address onBehalf) public returns (uint256) {
        return withdrawCollateral(underlying, amount, onBehalf, address(this));
    }

    function withdrawCollateral(address underlying, uint256 amount) public returns (uint256) {
        return withdrawCollateral(underlying, amount, address(this));
    }

    function liquidate(address underlyingBorrowed, address underlyingCollateral, address borrower, uint256 amount)
        external
        returns (uint256, uint256)
    {
        return morpho.liquidate(underlyingBorrowed, underlyingCollateral, borrower, amount);
    }

    function approveManager(address manager, bool isApproved) external {
        morpho.approveManager(manager, isApproved);
    }

    function depositVault(ERC4626UpgradeableSafe tokenizedVault, uint256 amount) external returns (uint256) {
        ERC20(tokenizedVault.asset()).safeApprove(address(tokenizedVault), amount);
        return tokenizedVault.deposit(amount, address(this));
    }

    function depositVault(ERC4626UpgradeableSafe tokenizedVault, uint256 amount, address to)
        external
        returns (uint256)
    {
        ERC20(tokenizedVault.asset()).safeApprove(address(tokenizedVault), amount);
        return tokenizedVault.deposit(amount, to);
    }

    function mintVault(ERC4626UpgradeableSafe tokenizedVault, uint256 shares) external returns (uint256) {
        ERC20(tokenizedVault.asset()).safeApprove(address(tokenizedVault), tokenizedVault.previewMint(shares));
        return tokenizedVault.mint(shares, address(this));
    }

    function mintVault(ERC4626UpgradeableSafe tokenizedVault, uint256 shares, address to) external returns (uint256) {
        ERC20(tokenizedVault.asset()).safeApprove(address(tokenizedVault), tokenizedVault.previewMint(shares));
        return tokenizedVault.mint(shares, to);
    }

    function withdrawVault(ERC4626UpgradeableSafe tokenizedVault, uint256 amount, address owner)
        public
        returns (uint256)
    {
        return tokenizedVault.withdraw(amount, address(this), owner);
    }

    function withdrawVault(ERC4626UpgradeableSafe tokenizedVault, uint256 amount, address receiver, address owner)
        public
        returns (uint256)
    {
        return tokenizedVault.withdraw(amount, receiver, owner);
    }

    function withdrawVault(ERC4626UpgradeableSafe tokenizedVault, uint256 amount) external returns (uint256) {
        return withdrawVault(tokenizedVault, amount, address(this));
    }

    function redeemVault(ERC4626UpgradeableSafe tokenizedVault, uint256 shares, address owner)
        public
        returns (uint256)
    {
        return tokenizedVault.redeem(shares, address(this), owner);
    }

    function redeemVault(ERC4626UpgradeableSafe tokenizedVault, uint256 shares, address receiver, address owner)
        public
        returns (uint256)
    {
        return tokenizedVault.redeem(shares, receiver, owner);
    }

    function redeemVault(ERC4626UpgradeableSafe tokenizedVault, uint256 shares) external returns (uint256) {
        return redeemVault(tokenizedVault, shares, address(this));
    }
}

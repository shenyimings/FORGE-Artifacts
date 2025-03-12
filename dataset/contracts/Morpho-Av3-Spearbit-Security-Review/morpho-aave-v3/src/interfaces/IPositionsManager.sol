// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.5.0;

interface IPositionsManager {
    function supplyLogic(address underlying, uint256 amount, address from, address onBehalf, uint256 maxIterations)
        external
        returns (uint256 supplied);

    function supplyCollateralLogic(address underlying, uint256 amount, address from, address onBehalf)
        external
        returns (uint256 supplied);

    function borrowLogic(address underlying, uint256 amount, address borrower, address receiver, uint256 maxIterations)
        external
        returns (uint256 borrowed);

    function repayLogic(address underlying, uint256 amount, address repayer, address onBehalf)
        external
        returns (uint256 repaid);

    function withdrawLogic(
        address underlying,
        uint256 amount,
        address supplier,
        address receiver,
        uint256 maxIterations
    ) external returns (uint256 withdrawn);
    function withdrawCollateralLogic(address underlying, uint256 amount, address supplier, address receiver)
        external
        returns (uint256 withdrawn);

    function liquidateLogic(
        address underlyingBorrowed,
        address underlyingCollateral,
        uint256 amount,
        address borrower,
        address liquidator
    ) external returns (uint256 liquidated, uint256 seized);
}

// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.5.0;

interface IWETHGateway {
    function WETH() external pure returns (address);
    function MORPHO() external view returns (address);
    function MORPHO_DAO() external pure returns (address);

    function skim(address erc20) external;

    function supplyETH(address onBehalf, uint256 maxIterations) external payable returns (uint256 supplied);
    function supplyCollateralETH(address onBehalf) external payable returns (uint256 supplied);
    function borrowETH(uint256 amount, address receiver, uint256 maxIterations) external returns (uint256 borrowed);
    function repayETH(address onBehalf) external payable returns (uint256 repaid);
    function withdrawETH(uint256 amount, address receiver, uint256 maxIterations)
        external
        returns (uint256 withdrawn);
    function withdrawCollateralETH(uint256 amount, address receiver) external returns (uint256 withdrawn);
}

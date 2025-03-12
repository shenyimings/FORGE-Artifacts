pragma solidity 0.7.6;


interface ILendingPoolCore {
    function getReserveATokenAddress(address _reserve) external view returns (address);
    function getReserveTotalLiquidity(address _reserve) external view returns (uint256);
    function getReserveAvailableLiquidity(address _reserve) external view returns (uint256);
    function getReserveCurrentLiquidityRate(address _reserve) external view returns (uint256);
    function getReserveUtilizationRate(address _reserve) external view returns (uint256);

    function getReserveTotalBorrowsStable(address _reserve) external view returns (uint256);
    function getReserveTotalBorrowsVariable(address _reserve) external view returns (uint256);
    function getReserveCurrentVariableBorrowRate(address _reserve) external view returns (uint256);
    function getReserveCurrentStableBorrowRate(address _reserve) external view returns (uint256);
    function getReserveCurrentAverageStableBorrowRate(address _reserve) external view returns (uint256);
}

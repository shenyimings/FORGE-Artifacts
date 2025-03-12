interface IBondingCurve {
    function calculatePurchaseReturn(uint256 _supply,  uint256 _reserveBalance, uint32 _reserveRatio, uint256 _depositAmount) external view returns (uint256);
}
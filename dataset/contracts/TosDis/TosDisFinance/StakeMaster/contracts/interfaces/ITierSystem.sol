pragma solidity 0.6.12;
interface ITierSystem {
    
    // function setTier(uint256 _vipDisAmount, uint256 _vipPercent, 
    //                  uint256 _holdersDisAmount, uint256 _holdersPercent, 
    //                  uint256 _publicDisAmount, uint256 _publicPercent) public;

    // function addBalances(address[] memory _addresses, uint256[] memory _balances) external;

    function getMaxEthPayment(address user, uint256 maxEthPayment)
        external
        view
        returns (uint256);
}
pragma solidity 0.6.12;

interface IPlanetFarmConfig {

    /// @dev Return the latest price for ETH-USD
    function getLatestPrice() external view returns (int);
    
    /// @dev Return the amount of Testa wei rewarded if we are activate the progress function
    function getTestaReward() external view returns (uint256);
    
    /// @dev Return the amount of Testa wei to spend upon harvesting reward
    function getTestaFee(uint256 rewardETH) external view returns (uint256);
    
    /// @dev Return the liquidity value required to activate the progres function
    function getRequiredLiquidity(uint256 startLiquidity) external view returns (uint256);

    /// @dev Return the current liquidity value.
    function getLiquidity() external view returns (uint112);

    /// @dev Return the company's contract address
    function getCompany() external view returns (address);
    
    /// @dev Return the first pay amount value
    function getPayAmount() external view returns (uint256);

    /// @dev Return the jTesta amount value
    function getJTestaAmount() external view returns (uint256);
    
    /// @dev Return the (min, max) progress bar values.
    function getProgressive() external view returns (int, int);
    
    /// @dev Return the amount of block required to activate the progress function.
    function getActivateAtBlock() external view returns (uint256);
}

pragma solidity ^0.8.0;

import "../interfaces/IMark2Market.sol";
import "../interfaces/IPortfolioManager.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockPortfolioManager is IPortfolioManager, IMark2Market {

    bool public navLess;
    address public navLessTo;
    uint256 public avgApy;
    IERC20 public asset;
    uint256 public totalRiskFactor;

    function setAsset(address _asset) external {
        asset = IERC20(_asset);
    }

    function setTotalRiskFactor(uint256 _totalRiskFactor) external {
        totalRiskFactor = _totalRiskFactor;
    }

    function setNavLess(bool value, address to) external {
        navLess = value;
        navLessTo = to;
    }


    function deposit(IERC20 _token, uint256 _amount) external override{

    }

    function withdraw(IERC20 _token, uint256 _amount) external override returns (uint256){

        if(navLess){
            asset.transfer(navLessTo, _amount);
        }else {
            asset.transfer(msg.sender, _amount);
        }
    }


    function totalNetAssets() external view override returns (uint256){
        return asset.balanceOf(address(this));
    }


    function getStrategyWeight(address strategy) external override view returns (StrategyWeight memory){
        revert('not implement');
    }

    function getAllStrategyWeights() external override view returns (StrategyWeight[] memory){
        revert('not implement');
    }

    function claimAndBalance() external override {

    }

    function balance() external override{

    }

    function strategyAssets() external view override returns (StrategyAsset[] memory){
        revert('not implement');
    }


    function totalLiquidationAssets() external view override returns (uint256){
        return 0;
    }

    function getTotalRiskFactor() external override view returns (uint256){
        return totalRiskFactor;
    }

}

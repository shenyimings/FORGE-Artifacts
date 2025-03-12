pragma solidity ^0.8.0;

import "../interfaces/IInsuranceExchange.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockInsuranceExchange is IInsuranceExchange {

    IERC20 public asset;

    function setAsset(address _asset) external {
        asset = IERC20(_asset);
    }


    function mint(InputMint calldata input) external override {

    }

    function redeem(InputRedeem calldata input) external override {

    }

    function payout() external override {

    }

    function premium(uint256 amount) external override {

    }

    function compensate(uint256 assetAmount, address to) external override{
        asset.transfer(to, assetAmount);
    }

    function requestWithdraw() external override{

    }

    function checkWithdraw() external override{

    }


}

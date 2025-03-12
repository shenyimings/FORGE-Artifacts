// SPDX-License-Identifier: MIT
/*
A bridge that connects AlphaHomora ibETH contracts to our STACK gauge contracts. 
This allows users to submit only one transaction to go from (supported ERC20 <-> AlphaHomora <-> STACK commit to VC fund)
They will be able to deposit & withdraw in both directions.
*/

pragma solidity ^0.6.11;

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol"; // call ERC20 safely
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "../Interfaces/IAlphaHomora_ibETH.sol";
import "../Interfaces/IGaugeD1.sol";

contract VaultGaugeBridge is ReentrancyGuard {
	using SafeERC20 for IERC20;
	using Address for address;
    using SafeMath for uint256;

    address payable public constant AlphaHomora_ibETH = 0xeEa3311250FE4c3268F8E684f7C87A82fF183Ec1; // AlphaHomora ibETHv2 deposit/withdraw contract & ERC20 contract

    address payable public governance;
    address public gauge;

    constructor () public {
    	governance = msg.sender;
    }

    receive() external payable {
        if (msg.sender != AlphaHomora_ibETH){
            // if the fund is open, then hard commit to the fund, if it's not, then fallback to soft commit
            if (IGaugeD1(gauge).fundOpen()){
                depositBridgeETH(true); 
            }
            else {
                depositBridgeETH(false);
            } 
        }
    }

    function setGovernance(address payable _new) external {
        require(msg.sender == governance, "BRIDGE: !governance");
        governance = _new;
    }

    // set the gauge to bridge ibETH to
    function setGauge(address _gauge) external {
    	require(msg.sender == governance, "BRIDGE: !governance");
        require(gauge == address(0), "BRIDGE: gauge already set");

    	gauge = _gauge;
    }

    // deposit ETH into ETH vault. WETH can be done with normal depositBridge call.
    // public because of fallback function
    function depositBridgeETH(bool _commit) nonReentrant public payable {
    	require(gauge != address(0), "BRIDGE: !bridge"); // need to setup, fail

    	uint256 _beforeToken = IERC20(AlphaHomora_ibETH).balanceOf(address(this));
    	IAlphaHomora_ibETH(AlphaHomora_ibETH).deposit{value: msg.value}();
    	uint256 _afterToken = IERC20(AlphaHomora_ibETH).balanceOf(address(this));
    	uint256 _receivedToken = _afterToken.sub(_beforeToken);

    	_depositGauge(_receivedToken, _commit, msg.sender);
    }

    // withdraw as ETH from WETH vault. WETH withdraw can be from from depositBridge call.
    function withdrawBridgeETH(uint256 _amount) nonReentrant external {
        require(gauge != address(0), "BRIDGE: !bridge"); // need to setup, fail

        uint256 _receivedToken = _withdrawGauge(_amount, msg.sender);

        uint256 _before = address(this).balance;
        IAlphaHomora_ibETH(AlphaHomora_ibETH).withdraw(_receivedToken);
        uint256 _after = address(this).balance;
        uint256 _received = _after.sub(_before);

        msg.sender.transfer(_received);
    }

    function _withdrawGauge(uint256 _amount, address _user) internal returns (uint256){
        uint256 _beforeToken = IERC20(AlphaHomora_ibETH).balanceOf(address(this));
        IGaugeD1(gauge).withdraw(_amount, _user);
        uint256 _afterToken = IERC20(AlphaHomora_ibETH).balanceOf(address(this));

        return _afterToken.sub(_beforeToken);
    }

    function _depositGauge(uint256 _amount, bool _commit, address _user) internal {
		IERC20(AlphaHomora_ibETH).safeApprove(gauge, 0);
    	IERC20(AlphaHomora_ibETH).safeApprove(gauge, _amount);

    	if (_commit){
    		IGaugeD1(gauge).deposit(0, _amount, _user);
    	}
    	else {
    		IGaugeD1(gauge).deposit(_amount, 0, _user);
    	}
    }

    // decentralized rescue function for any stuck tokens, will return to governance
    function rescue(address _token, uint256 _amount) nonReentrant external {
        require(msg.sender == governance, "BRIDGE: !governance");

        if (_token != address(0)){
            IERC20(_token).safeTransfer(governance, _amount);
        }
        else { // if _tokenContract is 0x0, then escape ETH
            governance.transfer(_amount);
        }
    }
}
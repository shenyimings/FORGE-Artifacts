// SPDX-License-Identifier: MIT
/*
A gauge to allow users to commit to Stacker.vc fund 1. This will reward STACK tokens for hard and soft commits, as well as link with a ibETH gateway, to allow users
to deposit ETH directly into the fund.

ibETH is sent to the STACK DAO governance contract, for future VC fund initialization.
*/

pragma solidity ^0.6.11;

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol"; // call ERC20 safely
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract GaugeD1 is ReentrancyGuard {
	using SafeERC20 for IERC20;
	using Address for address;
    using SafeMath for uint256;

    address payable public governance = 0xB156d2D9CAdB12a252A9015078fc5cb7E92e656e; // STACK DAO Agent address
    address public constant acceptToken = 0xeEa3311250FE4c3268F8E684f7C87A82fF183Ec1; // AlphaHomora ibETHv2
    address public vaultGaugeBridge; // the bridge address to allow people one transaction to do: (token <-> alphaHomora <-> commit)

    address public constant STACK = 0xe0955F26515d22E347B17669993FCeFcc73c3a0a; // STACK DAO Token

    uint256 public emissionRate = 127797160347097087; // 50k STACK total, div by delta block

    uint256 public depositedCommitSoft;
    uint256 public depositedCommitHard;

    uint256 public constant commitSoftWeight = 1;
    uint256 public constant commitHardWeight = 4;

    struct CommitState {
    	uint256 balanceCommitSoft;
    	uint256 balanceCommitHard;
    	uint256 tokensAccrued;
    }

    mapping(address => CommitState) public balances; // balance of acceptToken by user by commit

    event Deposit(address indexed from, uint256 amountCommitSoft, uint256 amountCommitHard);
    event Withdraw(address indexed to, uint256 amount);
    event Upgrade(address indexed user, uint256 amount);
    event STACKClaimed(address indexed to, uint256 amount);

    bool public fundOpen = true;

    uint256 public constant startBlock = 11955015;
    uint256 public endBlock = startBlock + 391245;

    uint256 public lastBlock; // last block the distribution has ran
    uint256 public tokensAccrued; // tokens to distribute per weight scaled by 1e18

    constructor(address _vaultGaugeBridge) public {
    	vaultGaugeBridge = _vaultGaugeBridge;
    }

    function setGovernance(address payable _new) external {
    	require(msg.sender == governance, "GAUGE: !governance");
    	governance = _new;
    }

    function setEmissionRate(uint256 _new) external {
    	require(msg.sender == governance, "GAUGE: !governance");
    	_kick(); // catch up the contract to the current block for old rate
    	emissionRate = _new;
    }

    function setEndBlock(uint256 _block) external {
    	require(msg.sender == governance, "GAUGE: !governance");
    	require(block.number <= endBlock, "GAUGE: distribution already done, must start another");
        require(block.number <= _block, "GAUGE: can't set endBlock to past block");

    	endBlock = _block;
    }

    function setFundOpen(bool _open) external {
        require(msg.sender == governance, "GAUGE: !governance");
        fundOpen = _open;
    }

    function deposit(uint256 _amountCommitSoft, uint256 _amountCommitHard, address _creditTo) nonReentrant external {
    	require(block.number <= endBlock, "GAUGE: distribution 1 over");
    	require(fundOpen || _amountCommitHard == 0, "GAUGE: !fundOpen, only soft commit allowed"); // when the fund closes, soft commits are still accepted
    	require(msg.sender == _creditTo || msg.sender == vaultGaugeBridge, "GAUGE: !bridge for creditTo"); // only the bridge contract can use the "creditTo" to credit !msg.sender

    	_claimSTACK(_creditTo); // new deposit doesn't get tokens right away

    	// transfer tokens from sender to account
    	uint256 _acceptTokenAmount = _amountCommitSoft.add(_amountCommitHard);
    	require(_acceptTokenAmount > 0, "GAUGE: !tokens");
    	IERC20(acceptToken).safeTransferFrom(msg.sender, address(this), _acceptTokenAmount);

    	CommitState memory _state = balances[_creditTo];
    	// no need to update _state.tokensAccrued because that's already done in _claimSTACK
    	if (_amountCommitSoft > 0){
    		_state.balanceCommitSoft = _state.balanceCommitSoft.add(_amountCommitSoft);
			depositedCommitSoft = depositedCommitSoft.add(_amountCommitSoft);
    	}
    	if (_amountCommitHard > 0){
    		_state.balanceCommitHard = _state.balanceCommitHard.add(_amountCommitHard);
			depositedCommitHard = depositedCommitHard.add(_amountCommitHard);

            IERC20(acceptToken).safeTransfer(governance, _amountCommitHard); // transfer out any hard commits right away
    	}

		emit Deposit(_creditTo, _amountCommitSoft, _amountCommitHard);
		balances[_creditTo] = _state;
    }

    function upgradeCommit(uint256 _amount) nonReentrant external {
    	// upgrading from soft -> hard commit
    	require(block.number <= endBlock, "GAUGE: distribution 1 over");
    	require(fundOpen, "GAUGE: !fundOpen"); // soft commits cannot be upgraded after the fund closes. they can be deposited though

    	_claimSTACK(msg.sender);

    	CommitState memory _state = balances[msg.sender];

        require(_amount <= _state.balanceCommitSoft, "GAUGE: insufficient balance softCommit");
        _state.balanceCommitSoft = _state.balanceCommitSoft.sub(_amount);
        _state.balanceCommitHard = _state.balanceCommitHard.add(_amount);
        depositedCommitSoft = depositedCommitSoft.sub(_amount);
        depositedCommitHard = depositedCommitHard.add(_amount);

        IERC20(acceptToken).safeTransfer(governance, _amount);

    	emit Upgrade(msg.sender, _amount);
    	balances[msg.sender] = _state;
    }

    // withdraw funds that haven't been committed to VC fund (fund in commitSoft before deadline)
    function withdraw(uint256 _amount, address _withdrawFor) nonReentrant external {
        require(block.number <= endBlock, ">endblock");
        require(msg.sender == _withdrawFor || msg.sender == vaultGaugeBridge, "GAUGE: !bridge for withdrawFor"); // only the bridge contract can use the "withdrawFor" to withdraw for !msg.sender 

    	_claimSTACK(_withdrawFor); // claim tokens from all blocks including this block on withdraw

    	CommitState memory _state = balances[_withdrawFor];

    	require(_amount <= _state.balanceCommitSoft, "GAUGE: insufficient balance softCommit");

    	// update globals & add amtToWithdraw to final tally.
    	_state.balanceCommitSoft = _state.balanceCommitSoft.sub(_amount);
    	depositedCommitSoft = depositedCommitSoft.sub(_amount);
    	
    	emit Withdraw(_withdrawFor, _amount);
    	balances[_withdrawFor] = _state;

    	// IMPORTANT: send tokens to msg.sender, not _withdrawFor. This will send to msg.sender OR vaultGaugeBridge (see second require() ).
        // the bridge contract will then forward these tokens to the sender (after withdrawing from yield farm)
    	IERC20(acceptToken).safeTransfer(msg.sender, _amount);
    }

    function claimSTACK() nonReentrant external returns (uint256) {
    	return _claimSTACK(msg.sender);
    }

    function _claimSTACK(address _user) internal returns (uint256){
    	_kick();

    	CommitState memory _state = balances[_user];
    	if (_state.tokensAccrued == tokensAccrued){ // user doesn't have any accrued tokens
    		return 0;
    	}
    	// user has accrued tokens from their commit
    	else {
    		uint256 _tokensAccruedDiff = tokensAccrued.sub(_state.tokensAccrued);
    		uint256 _tokensGive = _tokensAccruedDiff.mul(getUserWeight(_user)).div(1e18);

    		_state.tokensAccrued = tokensAccrued;
    		balances[_user] = _state;

    		// if the guage has enough tokens to grant the user, then send their tokens
            // otherwise, don't fail, just log STACK claimed, and a reimbursement can be done via chain events
            if (IERC20(STACK).balanceOf(address(this)) >= _tokensGive){
                IERC20(STACK).safeTransfer(_user, _tokensGive);
            }

            emit STACKClaimed(_user, _tokensGive);

            return _tokensGive;
    	}
    }

    function _kick() internal {   	
    	uint256 _totalWeight = getTotalWeight();
    	// if there are no tokens committed, then don't kick.
    	if (_totalWeight == 0){ 
    		return;
    	}
    	// already done for this block || already did all blocks || not started yet
    	if (lastBlock == block.number || lastBlock >= endBlock || block.number < startBlock){ 
    		return; 
    	}

		uint256 _deltaBlock;
		// edge case where kick was not called for the entire period of blocks.
		if (lastBlock <= startBlock && block.number >= endBlock){
			_deltaBlock = endBlock.sub(startBlock);
		}
		// where block.number is past the endBlock
		else if (block.number >= endBlock){
			_deltaBlock = endBlock.sub(lastBlock);
		}
		// where last block is before start
		else if (lastBlock <= startBlock){
			_deltaBlock = block.number.sub(startBlock);
		}
		// normal case, where we are in the middle of the distribution
		else {
			_deltaBlock = block.number.sub(lastBlock);
		}

		// mint tokens & update tokensAccrued global
		uint256 _tokensToAccrue = _deltaBlock.mul(emissionRate);
		tokensAccrued = tokensAccrued.add(_tokensToAccrue.mul(1e18).div(_totalWeight));

    	// if not allowed to mint it's just like the emission rate = 0. So just update the lastBlock.
    	// always update last block 
    	lastBlock = block.number;
    }

    // a one-time use function to sweep any commitSoft to the vc fund rewards pool, after the 3 month window
    function sweepCommitSoft() nonReentrant public {
    	require(block.number > endBlock, "GAUGE: <=endBlock");

        // transfer all remaining ERC20 tokens to the VC address. Fund entry has closed, VC fund will start.
    	IERC20(acceptToken).safeTransfer(governance, IERC20(acceptToken).balanceOf(address(this)));
    }

    function getTotalWeight() public view returns (uint256){
    	uint256 soft = depositedCommitSoft.mul(commitSoftWeight);
    	uint256 hard = depositedCommitHard.mul(commitHardWeight);

    	return soft.add(hard);
    }

    function getTotalBalance() public view returns(uint256){
    	return depositedCommitSoft.add(depositedCommitHard);
    }

    function getUserWeight(address _user) public view returns (uint256){
    	uint256 soft = balances[_user].balanceCommitSoft.mul(commitSoftWeight);
    	uint256 hard = balances[_user].balanceCommitHard.mul(commitHardWeight);

    	return soft.add(hard);
    }

    function getUserBalance(address _user) public view returns (uint256){
    	uint256 soft = balances[_user].balanceCommitSoft;
    	uint256 hard = balances[_user].balanceCommitHard;

    	return soft.add(hard);
    }

    function getCommitted() public view returns (uint256, uint256, uint256){
        return (depositedCommitSoft, depositedCommitHard, getTotalBalance());
    }

    // decentralized rescue function for any stuck tokens, will return to governance
    function rescue(address _token, uint256 _amount) nonReentrant external {
        require(msg.sender == governance, "GAUGE: !governance");

        if (_token != address(0)){
            IERC20(_token).safeTransfer(governance, _amount);
        }
        else { // if _tokenContract is 0x0, then escape ETH
            governance.transfer(_amount);
        }
    }
}
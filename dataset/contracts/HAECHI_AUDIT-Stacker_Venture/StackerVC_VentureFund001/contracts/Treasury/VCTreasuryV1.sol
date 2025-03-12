// SPDX-License-Identifier: MIT
/*
This is a Stacker.vc VC Treasury version 1 contract. It initiates a 1 year VC Fund that makes investments in ETH, and tries to sell previously acquired ERC20's at a profit.
This fund also has veto functionality by SVC001 token holders. A token holder can stop all buys and sells OR even close the fund early.
*/

pragma solidity ^0.6.11;
pragma experimental ABIEncoderV2; // for memory return types

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol"; // call ERC20 safely
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract VCTreasuryV1 is ERC20, ReentrancyGuard {
	using SafeERC20 for IERC20;
	using Address for address;
    using SafeMath for uint256;

	address public deployer;
	address payable public governance;

	enum FundStates {setup, active, paused, closed}
	FundStates public currentState;

	uint256 public fundStartTime;
	uint256 public fundCloseTime;

	uint256 public totalStakedToPause;
	uint256 public totalStakedToKill;
	mapping(address => uint256) stakedToPause;
	mapping(address => uint256) stakedToKill;
	bool public killed;
	address public constant BET_TOKEN = 0xfdd4E938Bb067280a52AC4e02AaF1502Cc882bA6;
	address public constant STACK_TOKEN = 0x514910771AF9Ca656af840dff83E8264EcF986CA; // TODO: need to deploy this contract, incorrect address, this is LINK token
	
	address public BASE_TOKEN; // fund will be denominated in stackETH, to generate interest on funds that aren't actively invested

	// we have some looping in the contract. have a limit for loops so that they succeed.
	// loops & especially unbounded loops are bad solidity design.
	uint256 public constant LOOP_LIMIT = 200; 

	// fixed once set
	uint256 public initETH;
	uint256 public constant investmentCap = 200; // percentage of initETH that can be invested of "max"
	uint256 public maxInvestment;

	uint256 public constant pauseQuorum = 300; // must be over this percent for a pause to take effect (of "max")
	uint256 public constant killQuorum = 500; // must be over this percent for a kill to take effect (of "max")
	uint256 public constant max = 1000;

	// used to determine total amount invested in last 30 days
	uint256 public currentInvestmentUtilization;
	uint256 public lastInvestTime;

	uint256 public constant ONE_YEAR = 365 days; // 365 days * 24 hours * 60 minutes * 60 seconds = 31,536,000
	uint256 public constant THIRTY_DAYS = 30 days; // 30 days * 24 hours * 60 minutes * 60 seconds = 2,592,000
	uint256 public constant THREE_DAYS = 3 days; // 3 days * 24 hours * 60 minutes * 60 seconds = 259,200
	uint256 public constant ONE_WEEK = 7 days; // 7 days * 24 hours * 60 minutes * 60 seconds = 604,800

	struct BuyProposal {
		uint256 buyId;
		address tokenAccept;
		uint256 amountInMin;
		uint256 ethOut;
		address taker;
		uint256 maxTime;
	}

	BuyProposal public currentBuyProposal; // only one buy proposal at a time, unlike sells
	uint256 public nextBuyId;
	mapping(address => bool) public boughtTokens; // a list of all tokens purchased (executed successfully)

	struct SellProposal {
		address tokenSell;
		uint256 ethInMin;
		uint256 amountOut;
		address taker;
		uint256 vetoTime;
		uint256 maxTime;
	}

	mapping(uint256 => SellProposal) public currentSellProposals; // can have multiple sells at a time
	uint256 public nextSellId;

	// fees, assessed after one year. fraction of `max`
	uint256 public constant DAOFee = 50;

	event InvestmentProposed(uint256 buyId, address tokenAccept, uint256 amountInMin, uint256 amountOut, address taker, uint256 maxTime);
	event InvestmentRevoked(uint256 buyId, uint256 time);
	event InvestmentExecuted(uint256 buyId, address tokenAccept, uint256 amountIn, uint256 amountOut, address taker, uint256 time);
	event DevestmentProposed(uint256 sellId, address tokenSell, uint256 ethInMin, uint256 amountOut, address taker, uint256 vetoTime, uint256 maxTime);
	event DevestmentRevoked(uint256 sellId, uint256 time);
	event DevestmentExecuted(uint256 sellId, address tokenSell, uint256 ethIn, uint256 amountOut, address taker, uint256 time);

	constructor(address payable _governance, address _baseToken) public ERC20("Stacker.vc Fund001", "SVC001") {
		deployer = msg.sender;
		governance = _governance;
		BASE_TOKEN = _baseToken;

		currentState = FundStates.setup;
		
		_setupDecimals(18);
	}

	// receive ETH, do nothing
	receive() payable external {
		return;
	}

	// change deployer account, only used for setup (no need to funnel setup calls thru multisig)
	function setDeployer(address _new) external {
		require(msg.sender == governance || msg.sender == deployer, "VCTREASURYV1: !(governance || deployer)");
		deployer = _new;
	}

	function setGovernance(address payable _new) external {
		require(msg.sender == governance, "VCTREASURYV1: !governance");
		governance = _new;
	}

	// mark a token as bought and able to be distributed when the fund closes. this would be for some sort of airdrop or "freely" acquired token sent to the contract
	function setBoughtToken(address _new) external {
		require(msg.sender == governance, "VCTREASURYV1: !governance");
		boughtTokens[_new] = true;
	}

	// mark a token as not bought, this would be some sort of token that is dangerous to be claimed after purchased, deprecated by a v2, etc.
	function unsetBoughtToken(address _new) external {
		require(msg.sender == governance, "VCTREASURYV1: !governance");
		boughtTokens[_new] = false;
	}

	// basic mapping get functions

	function getBoughtToken(address _token) external view returns (bool){
		return boughtTokens[_token];
	}

	function getStakedToPause(address _user) external view returns (uint256){
		return stakedToPause[_user];
	}

	function getStakedToKill(address _user) external view returns (uint256){
		return stakedToKill[_user];
	}

	function getSellProposal(uint256 _sellId) external view returns (SellProposal memory){
		return currentSellProposals[_sellId];
	}

	// start main logic
	
	// mint SVC001 tokens to users, fund cannot be started. SVC001 distribution must be audited and checked before the funds is started. Cannot mint tokens after fund starts.
	function issueTokens(address[] calldata _user, uint256[] calldata _amount) external {
		require(currentState == FundStates.setup, "VCTREASURYV1: !FundStates.setup");
		require(msg.sender == deployer || msg.sender == governance, "VCTREASURYV1: !(deployer || governance)");
		require(_user.length == _amount.length, "VCTREASURYV1: length mismatch");
		require(_user.length <= LOOP_LIMIT, "VCTREASURYV1: length > LOOP_LIMIT"); // don't allow unbounded loops, bad design, gas issues

		for (uint256 i = 0; i < _user.length; i++){
			_mint(_user[i], _amount[i]);
		}
	}

	// seed the fund with BASE_TOKEN and start it up. 1 year until fund is dissolved
	function startFund() external {
		require(currentState == FundStates.setup, "VCTREASURYV1: !FundStates.setup");
		require(msg.sender == governance, "VCTREASURYV1: !governance");
		require(totalSupply() > 0, "VCTREASURYV1: invalid setup"); // means fund tokens were not issued

		fundStartTime = block.timestamp;
		fundCloseTime = block.timestamp.add(ONE_YEAR);

		// fund must be sent BASE_TOKEN before calling this function
		initETH = IERC20(BASE_TOKEN).balanceOf(address(this));
		require(initETH > 0, "VCTREASURYV1: !initETH");
		maxInvestment = initETH.mul(investmentCap).div(max);

		_changeFundState(FundStates.active); // set fund active!
	}

	// make an offer to invest in a project by sending ETH to the project in exchange for tokens. one investment at a time. get ERC20, give ETH
	function investPropose(address _tokenAccept, uint256 _amountInMin, uint256 _ethOut, address _taker) external {
		_checkCloseTime();
		require(currentState == FundStates.active, "VCTREASURYV1: !FundStates.active");
		require(msg.sender == governance, "VCTREASURYV1: !governance");

		// checks that the investment utilization (30 day rolling average) isn't exceeded. will revert(). otherwise will update to new rolling average
		_updateInvestmentUtilization(_ethOut);

		BuyProposal memory _buy;
		_buy.buyId = nextBuyId;
		_buy.tokenAccept = _tokenAccept;
		_buy.amountInMin = _amountInMin;
		_buy.ethOut = _ethOut;
		_buy.taker = _taker;
		_buy.maxTime = block.timestamp.add(THREE_DAYS); // three days maximum to accept a buy

		currentBuyProposal = _buy;
		nextBuyId = nextBuyId.add(1);
		
		InvestmentProposed(_buy.buyId, _tokenAccept, _amountInMin, _ethOut, _taker, _buy.maxTime);
	}

	// revoke an uncompleted investment offer
	function investRevoke(uint256 _buyId) external {
		_checkCloseTime();
		require(currentState == FundStates.active || currentState == FundStates.paused, "VCTREASURYV1: !(FundStates.active || FundStates.paused)");
		require(msg.sender == governance, "VCTREASURYV1: !governance");

		BuyProposal memory _buy = currentBuyProposal;
		require(_buyId == _buy.buyId, "VCTREASURYV1: buyId not active");

		BuyProposal memory _reset;
		currentBuyProposal = _reset;

		InvestmentRevoked(_buy.buyId, block.timestamp);
	}

	// execute an investment offer by sending tokens to the contract, in exchange for ETH
	function investExecute(uint256 _buyId, uint256 _amount) nonReentrant external  {
		_checkCloseTime();
		require(currentState == FundStates.active, "VCTREASURYV1: !FundStates.active");

		BuyProposal memory _buy = currentBuyProposal;
		require(_buyId == _buy.buyId, "VCTREASURYV1: buyId not active");
		require(_buy.tokenAccept != address(0), "VCTREASURYV1: !tokenAccept");
		require(_amount >= _buy.amountInMin, "VCTREASURYV1: _amount < amountInMin");
		require(_buy.taker == msg.sender || _buy.taker == address(0), "VCTREASURYV1: !taker"); // if taker is set to 0x0, anyone can accept this investment
		require(block.timestamp <= _buy.maxTime, "VCTREASURYV1: time > maxTime");

		BuyProposal memory _reset;
		currentBuyProposal = _reset; // set investment proposal to a blank proposal, re-entrancy guard

		uint256 _before = IERC20(_buy.tokenAccept).balanceOf(address(this));
		IERC20(_buy.tokenAccept).safeTransferFrom(msg.sender, address(this), _amount);
		uint256 _after = IERC20(_buy.tokenAccept).balanceOf(address(this));
		require(_after.sub(_before) >= _buy.amountInMin, "VCTREASURYV1: received < amountInMin"); // check again to verify received amount was correct

		boughtTokens[_buy.tokenAccept] = true;

		InvestmentExecuted(_buy.buyId, _buy.tokenAccept, _amount, _buy.ethOut, msg.sender, block.timestamp);

		IERC20(BASE_TOKEN).safeTransfer(msg.sender, _buy.ethOut);
	}

	// allow advisory multisig to propose a new sell. get ETH, give ERC20 prior investment
	function devestPropose(address _tokenSell, uint256 _ethInMin, uint256 _amountOut, address _taker) external {
		_checkCloseTime();
		require(currentState == FundStates.active, "VCTREASURYV1: !FundStates.active");
		require(msg.sender == governance, "VCTREASURYV1: !governance");

		SellProposal memory _sell;
		_sell.tokenSell = _tokenSell;
		_sell.ethInMin = _ethInMin;
		_sell.amountOut = _amountOut;
		_sell.taker = _taker;
		_sell.vetoTime = block.timestamp.add(THREE_DAYS);
		_sell.maxTime = block.timestamp.add(THREE_DAYS).add(THREE_DAYS);

		currentSellProposals[nextSellId] = _sell;
		
		DevestmentProposed(nextSellId, _tokenSell, _ethInMin, _amountOut, _taker, _sell.vetoTime, _sell.maxTime);

		nextSellId = nextSellId.add(1);
	}

	// revoke an uncompleted sell offer
	function devestRevoke(uint256 _sellId) external {
		_checkCloseTime();
		require(currentState == FundStates.active || currentState == FundStates.paused, "VCTREASURYV1: !(FundStates.active || FundStates.paused)");
		require(msg.sender == governance, "VCTREASURYV1: !governance");
		require(_sellId < nextSellId, "VCTREASURYV1: !sellId");

		SellProposal memory _reset;
		currentSellProposals[_sellId] = _reset;

		DevestmentRevoked(_sellId, block.timestamp);
	}

	// execute a divestment of funds
	function devestExecute(uint256 _sellId, uint256 _ethIn) nonReentrant external {
		_checkCloseTime();
		require(currentState == FundStates.active, "VCTREASURYV1: !FundStates.active");

		SellProposal memory _sell = currentSellProposals[_sellId];
		require(_sell.tokenSell != address(0), "VCTREASURYV1: !tokenSell");
		require(_sell.taker == msg.sender || _sell.taker == address(0), "VCTREASURYV1: !taker"); // if taker is set to 0x0, anyone can accept this devestment
		require(block.timestamp > _sell.vetoTime, "VCTREASURYV1: time < vetoTime");
		require(block.timestamp <= _sell.maxTime, "VCTREASURYV1: time > maxTime");
		require(_ethIn >= _sell.ethInMin, "VCTREASURYV1: ethIn < ethInMin"); // initial sanity check

		uint256 _before = IERC20(BASE_TOKEN).balanceOf(address(this));
		IERC20(BASE_TOKEN).safeTransferFrom(msg.sender, address(this), _ethIn);
		uint256 _after = IERC20(BASE_TOKEN).balanceOf(address(this));
		uint256 _totalIn = _after.sub(_before);
		require(_totalIn >= _sell.ethInMin, "VCTREASURYV1: totalIn < ethInMin"); // actually transfer funds and check amount

		SellProposal memory _reset;
		currentSellProposals[_sellId] = _reset; // set devestment proposal to a blank proposal, re-entrancy guard

		DevestmentExecuted(_sellId, _sell.tokenSell, _totalIn, _sell.amountOut, msg.sender, block.timestamp);
		IERC20(_sell.tokenSell).safeTransfer(msg.sender, _sell.amountOut); // we already received _totalIn >= _sell.ethInMin, by above assertions

		// if we completely sell out of an asset, mark this as not owned anymore
		if (IERC20(_sell.tokenSell).balanceOf(address(this)) == 0){
			boughtTokens[_sell.tokenSell] = false;
		}
	}

	// stake SVC001 tokens to the fund. this signals unhappyness with the fund management
	// Pause: if 30% of SVC tokens are staked here, then all sells & buys will be disabled. They will be reenabled when tokens staked drops under 30%
	// tokens staked to stakeToKill() count as 
	function stakeToPause(uint256 _amount) external {
		_checkCloseTime();
		require(currentState == FundStates.active || currentState == FundStates.paused, "VCTREASURYV1: !(FundStates.active || FundStates.paused)");
		require(balanceOf(msg.sender) >= _amount, "VCTREASURYV1: insufficient balance to stakeToPause");

		_transfer(msg.sender, address(this), _amount);

		stakedToPause[msg.sender] = stakedToPause[msg.sender].add(_amount);
		totalStakedToPause = totalStakedToPause.add(_amount);

		_updateFundStateAfterStake();
	}

	// Kill: if 50% of SVC tokens are staked here, then the fund will close, and assets will be retreived
	// if 30% of tokens are staked here, then the fund will be paused. See above stakeToPause()
	function stakeToKill(uint256 _amount) external {
		_checkCloseTime();
		require(currentState == FundStates.active || currentState == FundStates.paused, "VCTREASURYV1: !(FundStates.active || FundStates.paused)");
		require(balanceOf(msg.sender) >= _amount, "VCTREASURYV1: insufficient balance to stakeToKill");

		_transfer(msg.sender, address(this), _amount);

		stakedToKill[msg.sender] = stakedToKill[msg.sender].add(_amount);
		totalStakedToKill = totalStakedToKill.add(_amount);

		_updateFundStateAfterStake();
	}

	function unstakeToPause(uint256 _amount) external {
		_checkCloseTime();
		require(currentState != FundStates.setup, "VCTREASURYV1: FundStates.setup");
		require(stakedToPause[msg.sender] >= _amount, "VCTREASURYV1: insufficent balance to unstakeToPause");

		_transfer(address(this), msg.sender, _amount);

		stakedToPause[msg.sender] = stakedToPause[msg.sender].sub(_amount);
		totalStakedToPause = totalStakedToPause.sub(_amount);

		_updateFundStateAfterStake();
	}

	function unstakeToKill(uint256 _amount) external {
		_checkCloseTime();
		require(currentState != FundStates.setup, "VCTREASURYV1: FundStates.setup");
		require(stakedToKill[msg.sender] >= _amount, "VCTREASURYV1: insufficent balance to unstakeToKill");

		_transfer(address(this), msg.sender, _amount);

		stakedToKill[msg.sender] = stakedToKill[msg.sender].sub(_amount);
		totalStakedToKill = totalStakedToKill.sub(_amount);

		_updateFundStateAfterStake();
	}

	function _updateFundStateAfterStake() internal {
		// closes are final, cannot unclose
		if (currentState == FundStates.closed){
			return;
		}
		// check if the fund will irreversibly close
		if (totalStakedToKill > killQuorumRequirement()){
			killed = true;
			_changeFundState(FundStates.closed);
			return;
		}
		// check if the fund will pause/unpause
		uint256 _pausedStake = totalStakedToPause.add(totalStakedToKill);
		if (_pausedStake > pauseQuorumRequirement() && currentState == FundStates.active){
			_changeFundState(FundStates.paused);
			return;
		}
		if (_pausedStake <= pauseQuorumRequirement() && currentState == FundStates.paused){
			_changeFundState(FundStates.active);
			return;
		}
	}

	function killQuorumRequirement() public view returns (uint256) {
		return totalSupply().mul(killQuorum).div(max);
	}

	function pauseQuorumRequirement() public view returns (uint256) {
		return totalSupply().mul(pauseQuorum).div(max);
	}

	function checkCloseTime() external {
		_checkCloseTime();
	}

	// maintenance function: check if the fund is out of time, if so, close it.
	function _checkCloseTime() internal {
		if (block.timestamp >= fundCloseTime && currentState != FundStates.setup){
			_changeFundState(FundStates.closed);
		}
	}

	function _changeFundState(FundStates _state) internal {
		// cannot be changed AWAY FROM closed or TO setup
		if (currentState == FundStates.closed || _state == FundStates.setup){
			return;
		}
		
		currentState = _state;
		// if closing the fund, assess the fee.
		if (_state == FundStates.closed){
			_assessFee();
		}
	}

	// when closing the fund, assess the fee for STACK holders/council. then close fund.
	function _assessFee() internal {
		uint256 _fee = totalSupply().mul(DAOFee).div(max);

		_mint(governance, _fee);
	}

	// fund is over, claim your proportional proceeds with SVC001 tokens. if fund is not closed but time's up, this will also close the fund
	function claim(address[] calldata _tokens) nonReentrant external {
		_checkCloseTime();
		require(currentState == FundStates.closed, "VCTREASURYV1: !FundStates.closed");
		require(_tokens.length <= LOOP_LIMIT, "VCTREASURYV1: length > LOOP_LIMIT"); // don't allow unbounded loops, bad design, gas issues

		// we should be able to send about 50 ERC20 tokens at a maximum in a loop
		// if we have more tokens than this in the fund, we can find a solution...
			// one would be wrapping all "valueless" tokens in another token (via sell / buy flow)
			// users can claim this bundled token, and if a "valueless" token ever has value, then they can do a similar cash out to the valueless token
			// there is a very low chance that there's >50 tokens that users want to claim. Probably more like 5-10 (given a normal VC story of many fails, some big successes)
		// we could alternatively make a different claim flow that doesn't use loops, but the gas and hassle of making 50 txs to claim 50 tokens is way worse

		uint256 _balance = balanceOf(msg.sender);
		uint256 _proportionE18 = _balance.mul(1e18).div(totalSupply());

		_burn(msg.sender, _balance);

		// automatically send a user their BASE_TOKEN balance, everyone wants BASE_TOKEN, the goal of the fund is to make BASE_TOKEN
		uint256 _proportionToken = IERC20(BASE_TOKEN).balanceOf(address(this)).mul(_proportionE18).div(1e18);
		IERC20(BASE_TOKEN).safeTransfer(msg.sender, _proportionToken);

		for (uint256 i = 0; i < _tokens.length; i++){
			require(_tokens[i] != address(this), "can't claim address(this)");
			require(boughtTokens[_tokens[i]], "!boughtToken");
			// don't allow BET/STACK to be claimed if the fund was "killed", these were "gifts" and not investments
			if (_tokens[i] == BET_TOKEN || _tokens[i] == STACK_TOKEN){
				require(!killed, "BET/STACK can only be claimed if fund wasn't killed");
			}

			_proportionToken = IERC20(_tokens[i]).balanceOf(address(this)).mul(_proportionE18).div(1e18);
			IERC20(_tokens[i]).safeTransfer(msg.sender, _proportionToken);
		}
	}

	// updates currentInvestmentUtilization based on a 30 day rolling average. If there are 30 days since the last investment, the utilization is zero. otherwise, deprec. it at a constant rate.
	function _updateInvestmentUtilization(uint256 _newInvestment) internal {
		uint256 proposedUtilization = getUtilization(_newInvestment);
		require(proposedUtilization <= maxInvestment, "VCTREASURYV1: utilization > maxInvestment");

		currentInvestmentUtilization = proposedUtilization;
		lastInvestTime = block.timestamp;
	}

	// get the total utilization from a possible _newInvestment
	function getUtilization(uint256 _newInvestment) public view returns (uint256){
		uint256 _lastInvestTimeDiff = block.timestamp.sub(lastInvestTime);
		if (_lastInvestTimeDiff >= THIRTY_DAYS){
			return _newInvestment;
		}
		else {
			// current * ((thirty_days - time elapsed) / thirty_days)
			uint256 _depreciateUtilization = currentInvestmentUtilization.div(THIRTY_DAYS).mul(THIRTY_DAYS.sub(_lastInvestTimeDiff));
			return _newInvestment.add(_depreciateUtilization);
		}
	}

	// get the maximum amount possible to invest at this time
	function availableToInvest() external view returns (uint256){
		return maxInvestment.sub(getUtilization(0));
	}

	// decentralized rescue function for any stuck tokens, will return to governance
    function rescue(address _token, uint256 _amount) nonReentrant external {
        require(msg.sender == governance, "!governance");

        if (_token != address(0)){
            IERC20(_token).safeTransfer(governance, _amount);
        }
        else { // if _tokenContract is 0x0, then escape ETH
            governance.transfer(_amount);
        }
    }
}
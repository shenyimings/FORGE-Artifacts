pragma abicoder v2;
pragma solidity >=0.7.6;

import './interfaces/IStakePoolCreator.sol';
import './interfaces/IStakePoolController.sol';
import './interfaces/IIsPair.sol';
import './interfaces/IStakePool.sol';
import './libraries/TransferHelper.sol';
import './TimeLock.sol';
import "./interfaces/IERC20.sol";
import './StakePoolRewardFund.sol';

contract StakePoolController is IStakePoolController {
    IIsPair public swapFactory;
    address public governance;

    address public feeCollector;
    address public feeToken;
    uint public  feeAmount;

    mapping(address => bool) private _stakePools;
    mapping(address => bool) private _whitelistStakingFor;
    mapping(address => bool) private _whitelistRewardRebaser;
    mapping(address => bool) private _whitelistRewardMultiplier;
    mapping(address => int8) private _whitelistStakePools;
    mapping(address => bool) public _stakePoolVerifiers;
    mapping(uint => address) public stakePoolCreators;
    address[] public override allStakePools;
    bool public enableWhitelistRewardRebaser = true;
    bool public enableWhitelistRewardMultiplier = true;
    bool private _initialized = false;

    mapping(address => bool) public allowEmergencyWithdrawStakePools;

    uint public extraFeeRate;

    function initialize(address _swapFactory) public {
        require(_initialized == false, "StakePoolController: initialized");
        governance = msg.sender;
        swapFactory = IIsPair(_swapFactory);
        _initialized = true;
    }

    function isStakePool(address b) external override view returns (bool){
        return _stakePools[b];
    }

    modifier onlyGovernance() {
        require(msg.sender == governance, "StakePoolController: !governance");
        _;
    }

    function setFeeCollector(address _address) external onlyGovernance override {
        require(_address != address(0), "StakePoolController: invalid address");
        feeCollector = _address;
        emit SetFeeCollector(_address);
    }
    function setEnableWhitelistRewardRebaser(bool value) external onlyGovernance override {
        enableWhitelistRewardRebaser = value;
    }
    function setEnableWhitelistRewardMultiplier(bool value) external onlyGovernance override {
        enableWhitelistRewardMultiplier = value;
    }
    function setFeeToken(address _token) external onlyGovernance override {
        require(_token != address(0), "StakePoolController: invalid _token");
        feeToken = _token;
        emit SetFeeToken(_token);
    }
    function getCreationFee(address token) public view returns (uint) {
        if (swapFactory.isPair(token)) {
            return feeAmount;
        }
        return feeAmount * extraFeeRate / 1000;
    }
    function setFeeAmount(uint _feeAmount) external onlyGovernance override {
        feeAmount = _feeAmount;
        emit SetFeeAmount(_feeAmount);
    }
    function setExtraFeeRate(uint _extraFeeRate) external onlyGovernance override {
        require(_extraFeeRate >= 1000 && _extraFeeRate <= 50000, "StakePoolController: invalid _extraFeeRate");
        extraFeeRate = _extraFeeRate;
        emit SetExtraFeeRate(_extraFeeRate);
    }
    function isWhitelistStakingFor(address _address) external override view returns (bool){
        return _whitelistStakingFor[_address];
    }

    function isWhitelistStakePool(address _address) external override view returns (int8){
        return _whitelistStakePools[_address];
    }
    function isStakePoolVerifier(address _address) external override view returns (bool){
        return _stakePoolVerifiers[_address];
    }
    function isAllowEmergencyWithdrawStakePool(address _address) external override view returns (bool){
        return allowEmergencyWithdrawStakePools[_address];
    }
    function setWhitelistStakingFor(address _address, bool state) external onlyGovernance override {
        require(_address != address(0), "StakePoolController: invalid address");
        _whitelistStakingFor[_address] = state;
        emit SetWhitelistStakingFor(_address, state);
    }
    function setAllowEmergencyWithdrawStakePool(address _address, bool state) external onlyGovernance override {
        require(_address != address(0), "StakePoolController: invalid address");
        allowEmergencyWithdrawStakePools[_address] = state;
    }

    function setStakePoolVerifier(address _address, bool state) external onlyGovernance override {
        require(_address != address(0), "StakePoolController: invalid address");
        _stakePoolVerifiers[_address] = state;
        emit SetStakePoolVerifier(_address, state);
    }

    function setWhitelistStakePool(address _address, int8 state) external override {
        require(_address != address(0), "StakePoolController: invalid address");
        require(_stakePoolVerifiers[msg.sender] == true, "StakePoolController: invalid stake pool verifier");
        _whitelistStakePools[_address] = state;
        emit SetWhitelistStakePool(_address, state);
    }

    function addStakePoolCreator(address _address) external onlyGovernance override {
        require(_address != address(0), "StakePoolController: invalid address");
        uint version = IStakePoolCreator(_address).version();
        require(version >= 1000, "Invalid stake pool creator version");
        stakePoolCreators[version] = _address;
        emit SetStakePoolCreator(_address, version);
    }

    function isWhitelistRewardRebaser(address _address) external override view returns (bool){
        if (!enableWhitelistRewardRebaser) return true;
        return _address == address(0) ? true : _whitelistRewardRebaser[_address];
    }

    function setWhitelistRewardRebaser(address _address, bool state) external onlyGovernance override {
        require(_address != address(0), "StakePoolController: invalid address");
        _whitelistRewardRebaser[_address] = state;
        emit SetWhitelistRewardRebaser(_address, state);
    }

    function isWhitelistRewardMultiplier(address _address) external override view returns (bool){
        if (!enableWhitelistRewardMultiplier) return true;
        return _address == address(0) ? true : _whitelistRewardMultiplier[_address];
    }

    function setWhitelistRewardMultiplier(address _address, bool state) external onlyGovernance override {
        require(_address != address(0), "StakePoolController: invalid address");
        _whitelistRewardMultiplier[_address] = state;
        emit SetWhitelistRewardMultiplier(_address, state);
    }

    function setGovernance(address _governance) external onlyGovernance override {
        require(_governance != address(0), "StakePoolController: invalid governance");
        governance = _governance;
        emit ChangeGovernance(_governance);
    }

    function allStakePoolsLength() external override view returns (uint) {
        return allStakePools.length;
    }
    function createInternal(address stakePoolCreator, address stakeToken, address stakePoolRewardFund, address rewardToken, uint delayTimeLock, bytes calldata data) internal returns (address) {
        TimeLock timelock = new TimeLock();
        IStakePool pool = IStakePool(IStakePoolCreator(stakePoolCreator).create());
        allStakePools.push(address(pool));
        _stakePools[address(pool)] = true;
        emit MasterCreated(address(pool), stakeToken, pool.version(), address(timelock), stakePoolRewardFund, allStakePools.length);
        IStakePoolCreator(stakePoolCreator).initialize(address(pool), stakeToken, rewardToken, address(timelock), address(stakePoolRewardFund), data);
        StakePoolRewardFund(stakePoolRewardFund).initialize(address(pool), address(timelock));
        timelock.initialize(msg.sender, delayTimeLock);
        return address(pool);
    }
    function create(uint version, address stakeToken, address rewardToken, uint rewardFundAmount, uint delayTimeLock, bytes calldata data) public override returns (address) {
        address stakePoolCreator = stakePoolCreators[version];
        require(stakePoolCreator != address(0), "StakePoolController: Invalid stake pool creator version");
        uint creationFee = getCreationFee(stakeToken);
        if (feeCollector != address(0) && feeToken != address(0) && creationFee > 0) {
            TransferHelper.safeTransferFrom(feeToken, msg.sender, feeCollector, creationFee);
        }

        StakePoolRewardFund stakePoolRewardFund = new StakePoolRewardFund();
        if (rewardFundAmount > 0) {
            require(IERC20(rewardToken).balanceOf(msg.sender) >= rewardFundAmount , "StakePoolController: Not enough rewardFundAmount");
            TransferHelper.safeTransferFrom(rewardToken, msg.sender, address(stakePoolRewardFund), rewardFundAmount);
        }
        return createInternal(stakePoolCreator, stakeToken, address(stakePoolRewardFund), rewardToken, delayTimeLock, data);
    }
}

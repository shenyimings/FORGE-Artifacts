pragma solidity =0.6.12;

import '../interfaces/IStableSwapFactory.sol';
import '../interfaces/ISwapCreator.sol';
import '../TimeLock.sol';
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

contract StableSwapFactory is IStableSwapFactory {
    using SafeERC20 for IERC20;

    address public override feeTo;
    address public override feeToSetter;
    address public feeToken;
    uint public feeAmount;

    address[] public override allPools;
    mapping(address => bool) private _pools;
    mapping(address => bool) private _timelocks;
    ISwapCreator public swapCreator;
    bool private _initialized = false;

    function initialize(address _feeToSetter, ISwapCreator _swapCreator) public {
        require(_initialized == false, "StableSwapFactory: initialized");
        feeToSetter = _feeToSetter;
        swapCreator = _swapCreator;
        _initialized = true;
    }

    function isPool(address b) external override view returns (bool) {
        return _pools[b];
    }

    function isTimelock(address b) external override view returns (bool) {
        return _timelocks[b];
    }

    function allPoolsLength() external override view returns (uint) {
        return allPools.length;
    }

    function createPool(
        IERC20[] memory _pooledTokens,
        uint8[] memory decimals,
        string memory lpTokenName,
        string memory lpTokenSymbol,
        uint256 _a,
        uint256 _fee,
        uint256 _adminFee,
        uint256 _withdrawFee,
        uint delayTimeLock
    ) external override returns (address) {
        TimeLock timelock = new TimeLock();
        address swap = createPoolInternal(
            _pooledTokens,
            decimals,
            lpTokenName,
            lpTokenSymbol,
            _a,
            _fee,
            _adminFee,
            _withdrawFee,
            address(timelock)
        );

        timelock.initialize(msg.sender, delayTimeLock);
        _timelocks[address(timelock)] = true;
        return swap;
    }

    function createPoolInternal(
        IERC20[] memory _pooledTokens,
        uint8[] memory decimals,
        string memory lpTokenName,
        string memory lpTokenSymbol,
        uint256 _a,
        uint256 _fee,
        uint256 _adminFee,
        uint256 _withdrawFee,
        address timeLock
    ) public returns (address) {
        if (feeTo != address(0) && feeToken != address(0) && feeAmount > 0) {
            IERC20(feeToken).safeTransferFrom(msg.sender, feeTo, feeAmount);
        }

        address swap = ISwapCreator(swapCreator).create(
            _pooledTokens,
            decimals,
            lpTokenName,
            lpTokenSymbol,
            _a,
            _fee,
            _adminFee,
            _withdrawFee,
            timeLock
        );

        allPools.push(swap);
        _pools[swap] = true;
        emit SwapCreated(_pooledTokens, swap, allPools.length);
        return swap;
    }

    function setSwapCreator(ISwapCreator _swapCreator) external {
        require(msg.sender == feeToSetter, 'FLP: FORBIDDEN');
        swapCreator = _swapCreator;
    }

    function setFeeTo(address _feeTo) external override {
        require(msg.sender == feeToSetter, 'FLP: FORBIDDEN');
        feeTo = _feeTo;
        emit SetFeeTo(_feeTo);
    }

    function setFeeToSetter(address _feeToSetter) external override {
        require(msg.sender == feeToSetter, 'FLP: FORBIDDEN');
        feeToSetter = _feeToSetter;
    }

    function setFeeToken(address _token) external override {
        require(msg.sender == feeToSetter, 'FLP: FORBIDDEN');
        feeToken = _token;
        emit SetFeeToken(_token);
    }

    function setFeeAmount(uint _feeAmount) external override {
        require(msg.sender == feeToSetter, 'FLP: FORBIDDEN');
        feeAmount = _feeAmount;
        emit SetFeeAmount(_feeAmount);
    }
}

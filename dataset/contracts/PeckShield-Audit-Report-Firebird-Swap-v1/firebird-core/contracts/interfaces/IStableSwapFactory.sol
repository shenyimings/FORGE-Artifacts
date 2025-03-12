pragma solidity >=0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IStableSwapFactory {
    event SwapCreated(IERC20[] pooledTokens, address indexed swap, uint length);
    event SetFeeTo(address indexed feeTo);
    event SetFeeToken(address indexed token);
    event SetFeeAmount(uint indexed amount);

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);

    function allPools(uint) external view returns (address pool);
    function isPool(address) external view returns (bool);
    function allPoolsLength() external view returns (uint);

    function isTimelock(address) external view returns (bool);

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
    ) external returns (address pool);

    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
    function setFeeToken(address _token) external;
    function setFeeAmount(uint _token) external;
}

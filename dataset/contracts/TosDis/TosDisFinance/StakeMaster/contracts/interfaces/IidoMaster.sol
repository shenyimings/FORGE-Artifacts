pragma solidity 0.6.12;
import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";
interface IidoMaster {
    
    function feeToken() external pure returns (ERC20Burnable);
    function feeWallet() external pure returns (address payable);

    function feeAmount() external pure returns (uint256);
    function burnPercent() external pure returns (uint256);
    function divider() external pure returns (uint256);
    function feeFundsPercent() external pure returns (uint256);

    function registrateIDO(
        address _poolAddress,
        uint256 _tokenPrice,
        address _payableToken,
        address _rewardToken,
        uint256 _startTimestamp,
        uint256 _finishTimestamp,
        uint256 _startClaimTimestamp,
        uint256 _minEthPayment,
        uint256 _maxEthPayment,
        uint256 _maxDistributedTokenAmount
    ) external;

    // function getMaxEthPayment(address user, uint256 maxEthPayment)
    //     external
    //     view
    //     returns (uint256);

    // function getFullDisBalance(address user)
    //     external
    //     view     
    //     returns (uint256);
}
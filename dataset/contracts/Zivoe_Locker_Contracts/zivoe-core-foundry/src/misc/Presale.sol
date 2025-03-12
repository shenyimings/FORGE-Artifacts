// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../libraries/OwnableLocked.sol";

import "../../lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IPresale_Oracle {
    /// @notice Returns the latest answer (price) from the oracle.
    function latestAnswer() external view returns (int256);
}

/// @notice This contract facilitates a presale for Zivoe.
contract Presale is OwnableLocked, ReentrancyGuard {

    using SafeERC20 for IERC20;

    // ---------------------
    //    State Variables
    // ---------------------

    address public oracle;                  /// @dev Chainlink oracle for ETH.

    address public treasury;                /// @dev The treasury for the presale.

    uint public pointsFloor = 250;          /// @dev Minimum amount of points earnable, per stablecoin deposit.

    uint public pointsCeiling = 5000;       /// @dev Maximum amount of points earnable, per stablecoin deposit.

    uint public presaleStart;               /// @dev The timestamp at which the presale starts.
    
    uint public presaleDuration = 21 days;  /// @dev The amount of time presale lasts.

    mapping(address => bool) public stablecoinWhitelist;    /// @dev Whitelist for stablecoins.

    mapping(address => uint) public points;    /// @dev Track points per user.



    // -----------------
    //    Constructor
    // -----------------

    /// @notice Initializes the Presale contract.
    /// @param  stablecoins The permitted stablecoins for deposit.
    /// @param  _oracle Chainlink oracle for ETH.
    /// @param  _treasury Chainlink oracle for ETH.
    constructor(address[] memory stablecoins, address _oracle, address _treasury) {

        // DAI, FRAX, USDC, USDT
        stablecoinWhitelist[stablecoins[0]] = true;
        stablecoinWhitelist[stablecoins[1]] = true;
        stablecoinWhitelist[stablecoins[2]] = true;
        stablecoinWhitelist[stablecoins[3]] = true;

        oracle = _oracle;

        treasury = _treasury;

        presaleStart = block.timestamp + 1 days;

    }



    // ------------
    //    Events
    // ------------

    /// @notice Emitted during depositStablecoin().
    /// @param  depositor The person depositing stablecoins.
    /// @param  stablecoin The stablecoin deposited.
    /// @param  amount The amount of stablecoin deposited.
    /// @param  pointsAwarded The amount of points awarded to depositor.
    event StablecoinDeposited(
        address indexed depositor,
        address indexed stablecoin,
        uint256 amount,
        uint256 pointsAwarded
    );

    /// @notice Emitted during depositETH().
    /// @param  depositor The person depositing ETH.
    /// @param  amount The amount of ETH deposited.
    /// @param  oraclePrice The current oracle price of ETH.
    /// @param  pointsAwarded The amount of points awarded to depositor.
    event ETHDeposited(
        address indexed depositor,
        uint256 amount,
        uint256 oraclePrice,
        uint256 pointsAwarded
    );



    // ---------------
    //    Functions
    // ---------------

    /// @notice Read data for price point from Chainlink oracle.
    /// @return price The price, which assumes the precision is 10**8 units.
    function oraclePrice() public view returns (uint256 price) {
        price = uint(IPresale_Oracle(oracle).latestAnswer());
    }

    /// @notice Calculates points multiplier based on current day, for stablecoins.
    /// @param  stablecoin The stablecoin deposited.
    /// @param  amount The amount of stablecoin deposited.
    function pointsAwardedStablecoin(address stablecoin, uint256 amount) public view returns(uint256 pointsAwarded) {
        uint256 amountDeposited = standardize(stablecoin, amount);
        pointsAwarded = (amountDeposited) * (
            pointsFloor + (pointsCeiling - pointsFloor) * (21 days - (block.timestamp - presaleStart)) / 21 days
        );
    }

    /// @notice Calculates points multiplier based on current day, for ETH.
    /// @param  amount The amount of ETH deposited.
    function pointsAwardedETH(uint256 amount) public view returns(uint256 pointsAwarded, uint256 priceEth) {
        priceEth = oraclePrice();
        pointsAwarded = (
            (priceEth * amount) / (10**8)
        ) * (
            pointsFloor + (pointsCeiling - pointsFloor) * (21 days - (block.timestamp - presaleStart)) / 21 days
        );
    }

    /// @notice Handles WEI standardization of a given asset amount (i.e. 6 decimal precision => 18 decimal precision).
    /// @param  stablecoin          The stablecoin from which to standardize the amount to WEI.
    /// @param  amount              The amount of a given "asset".
    /// @return standardizedAmount  The input "amount" standardized to 18 decimals.
    function standardize(address stablecoin, uint256 amount) public view returns (uint256 standardizedAmount) {
        standardizedAmount = amount;
        if (IERC20Metadata(stablecoin).decimals() < 18) { 
            standardizedAmount *= 10 ** (18 - IERC20Metadata(stablecoin).decimals()); 
        } 
        else if (IERC20Metadata(stablecoin).decimals() > 18) { 
            standardizedAmount /= 10 ** (IERC20Metadata(stablecoin).decimals() - 18);
        }
    }

    /// @notice Handles deposits for stablecoins, awards points to depositor.
    /// @param  stablecoin The stablecoin to deposit.
    /// @param  amount The amount of stablecoin to deposit.
    function depositStablecoin(address stablecoin, uint256 amount) public {
        require(block.timestamp > presaleStart, "Presale::depositStablecoin() block.timestamp <= presaleStart");
        require(
            block.timestamp < presaleStart + presaleDuration, 
            "Presale::depositStablecoin() block.timestamp >= presaleStart + presaleDuration"
        );
        require(stablecoinWhitelist[stablecoin], "Presale::depositStablecoin() !stablecoinWhitelist[stablecoin]");
        
        // Enforce minimum 10
        uint checkAmount = standardize(stablecoin, amount);
        require(checkAmount >= 10 ether, "Presale::depositStablecoin() checkAmount < 10 ether");

        IERC20(stablecoin).transferFrom(_msgSender(), treasury, amount);

        // Points awarded is equivalent to amount deposited, converted to 10**18 precision (wei).
        uint256 pointsAwarded = pointsAwardedStablecoin(stablecoin, amount);
        points[_msgSender()] += pointsAwarded;
        emit StablecoinDeposited(_msgSender(), stablecoin, amount, pointsAwarded);
    }

    /// @notice Handles deposits for ETH, awards points to depositor.
    function depositETH() nonReentrant public payable {
        require(block.timestamp > presaleStart, "Presale::depositETH() block.timestamp <= presaleStart");
        require(
            block.timestamp < presaleStart + presaleDuration, 
            "Presale::depositETH() block.timestamp >= presaleStart + presaleDuration"
        );

        // Enforce minimum 0.01 ETH, transfer and confirm
        require(msg.value >= 0.01 ether, "Presale::depositETH() msg.value < 0.01 ether");
        bool forward = payable(treasury).send(msg.value);
        require(forward, "Presale::depositETH() !forward");

        // Points awarded is equivalent to amount deposited multipled by oracle price, which is 10**18 precision (wei).
        (uint256 pointsAwarded, uint256 price) = pointsAwardedETH(msg.value);
        points[_msgSender()] += pointsAwarded;
        emit ETHDeposited(_msgSender(), msg.value, price, pointsAwarded);
    }

    /// @notice Receive function implemented for ETH transfer support.
    receive() external payable {}

    /// @notice Fallback function implemented for ETH transfer support.
    fallback() external payable {}

}
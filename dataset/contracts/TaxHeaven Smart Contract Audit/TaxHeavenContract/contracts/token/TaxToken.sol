// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;

import "../../node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../../node_modules/@openzeppelin/contracts/math/SafeMath.sol";
import "../../node_modules/@openzeppelin/contracts/utils/SafeCast.sol";
import "./Whitelist.sol";
import "../oracle/OracleInterface.sol";

contract TaxToken is ERC20("TAX", "TAX"), Whitelist {
    using SafeMath for uint256;
    using SafeMath for uint128;
    using SafeCast for uint256;

    /* ========== CONSTANT VARIABLES ========== */

    address internal immutable _deployer;
    uint256 internal immutable _halvingStartLendValue;
    uint256 internal immutable _maxTotalSupply;
    uint256 internal immutable _initialMintUnit;
    uint256 internal immutable _developerFundRateE8;
    uint256 internal immutable _incentiveFundRateE8;

    /* ========== STATE VARIABLES ========== */

    address[] internal _incentiveFundAddresses;
    uint256[] internal _incentiveFundAllocationE8;

    uint128 internal _developerFund;
    uint128 internal _incentiveFund;
    uint128 internal _totalLendValue;

    address internal _governanceAddress;
    address internal _developer;
    address internal _lendingAddress;

    mapping(address => address) internal _tokenPriceOracle;

    /* ========== EVENTS ========== */

    event LogUpdateGovernanceAddress(address newAddress);
    event LogUpdateLendingAddress(address newAddress);
    event LogRegisterWhitelist(address tokenAddress, address oracleAddress);
    event LogUnregisterWhitelist(address tokenAddress);
    event LogUpdateIncentiveAddresses(
        address[] newIncentiveAddresses,
        uint256[] newIncentiveAllocationE8
    );

    /* ========== CONSTRUCTOR ========== */

    constructor(
        address governanceAddress,
        address developer,
        address[] memory incentiveFundAddresses,
        uint256[] memory incentiveFundAllocationE8,
        uint256 developerFundRateE8,
        uint256 incentiveFundRateE8,
        address lendingAddress,
        uint256 halvingStartLendValue,
        uint256 maxTotalSupply,
        uint256 initialMintUnit
    ) {
        _deployer = msg.sender;
        _governanceAddress = governanceAddress; // governance address can update or delete whitelist
        _developer = developer; // developer fund address
        _incentiveFundAddresses = incentiveFundAddresses; // incentive fund addresses. ex) uniswap share token staking contract address
        _incentiveFundAllocationE8 = incentiveFundAllocationE8; //[0.3 * 10**8, 0.7 * 10**8]. sum should be 10**8
        _developerFundRateE8 = developerFundRateE8; // developer fund rate. when 5%, should be set as 0.05 * 10**8
        _incentiveFundRateE8 = incentiveFundRateE8; // incentive fund rate. when 10%, should be set as 0.1 * 10**8
        _lendingAddress = lendingAddress; // lending contract address
        _halvingStartLendValue = halvingStartLendValue; // the amount of totalLendValue that initial halving occurs. set at 2 * 10**8 = 200M dollar
        _maxTotalSupply = maxTotalSupply; // total supply of tax token, set at 1 * 10**9 * 10**18 = 1B tax
        _initialMintUnit = initialMintUnit; // amount to mint per unit, set at 1 * 10**18

        require(
            _incentiveFundAddresses.length == _incentiveFundAllocationE8.length,
            "the length of the addresses and their allocation should be the same"
        );
        uint256 sumcheck = 0;
        for (uint256 i = 0; i < _incentiveFundAllocationE8.length; i++) {
            sumcheck = sumcheck.add(_incentiveFundAllocationE8[i]);
        }
        require(sumcheck == 10**8, "the sum of the allocation should be 10**8");
    }

    /* ========== MODIFIERS ========== */

    modifier onlyGovernance() {
        require(msg.sender == _governanceAddress, "only governance address can call");
        _;
    }

    modifier onlyLending() {
        require(msg.sender == _lendingAddress, "only lending contract address can call");
        _;
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    /**
     * @notice mint token only when the lended ERC20 is whitelisted.
     * @dev this contract will not function when the total lend value of whitelisted tokens exceeds 2**128 dollar.
     * this contract will lose value when the oracle of the whitelisted tokens collapses and returns an extraordinary large number.
     */
    function mintToken(
        address tokenAddress,
        uint256 lendAmount,
        address recipient
    ) external onlyLending {
        if (_maxTotalSupply == totalSupply()) {
            return;
        }
        uint8 decimalsOfLendingToken = 18; // decimals of ETH
        if (tokenAddress != address(0)) {
            decimalsOfLendingToken = ERC20(tokenAddress).decimals();
        }

        address oracle = _tokenPriceOracle[tokenAddress];
        uint256 mintAmount = 0;
        if (oracle != address(0)) {
            OracleInterface oracleContract = OracleInterface(oracle);
            uint256 price = uint256(oracleContract.latestAnswer());
            uint8 decimalsOfOraclePrice = oracleContract.decimals();
            uint256 asOfMintUnit = _getMintUnit();
            uint256 lendValue = lendAmount.mul(price).div(
                10**uint256(decimalsOfOraclePrice + decimalsOfLendingToken)
            );
            _totalLendValue = _totalLendValue.add(lendValue).toUint128();
            mintAmount = lendValue.mul(asOfMintUnit);
            uint256 remainingMintableAmount = _maxTotalSupply.sub(
                totalSupply().add(_developerFund).add(_incentiveFund)
            );
            mintAmount = remainingMintableAmount >= mintAmount
                ? mintAmount
                : remainingMintableAmount;
        }
        if (mintAmount != 0) {
            uint256 devFund = mintAmount.mul(_developerFundRateE8) / 10**8;
            uint256 incFund = mintAmount.mul(_incentiveFundRateE8) / 10**8;
            _developerFund = _developerFund.add(devFund).toUint128();
            _incentiveFund = _incentiveFund.add(incFund).toUint128();
            _mint(recipient, mintAmount.sub(devFund).sub(incFund));
        }
    }

    /**
     * @notice governanceAddress can add/override ERC20 token to the whitelist with the oracle address.
     * any ERC20 token can use the lending contract, but only the whitelisted addresses can earn tax token.
     */
    function registerWhitelist(address tokenAddress, address oracleAddress)
        external
        onlyGovernance
    {
        OracleInterface oracleContract = OracleInterface(oracleAddress);
        oracleContract.decimals();
        oracleContract.latestAnswer();

        _tokenPriceOracle[tokenAddress] = oracleAddress;
        _addWhitelist(tokenAddress);

        emit LogRegisterWhitelist(tokenAddress, oracleAddress);
    }

    /**
     * @notice governanceAddress can delist from the whitelist.
     */
    function unregisterWhitelist(address tokenAddress) external onlyGovernance {
        delete _tokenPriceOracle[tokenAddress];
        _removeWhitelist(tokenAddress);

        emit LogUnregisterWhitelist(tokenAddress);
    }

    /**
     * @notice lendingAddress can be updated by the deployer.
     * @dev can be used only before the deployer transfers the rights of governance
     */
    function updateLendingAddress(address newLendingAddress) external onlyGovernance {
        _lendingAddress = newLendingAddress;

        emit LogUpdateLendingAddress(newLendingAddress);
    }

    /**
     * @notice only governance contract can update incentive addresses and their allocation.
     */
    function updateIncentiveAddresses(
        address[] memory newIncentiveAddresses,
        uint256[] memory newIncentiveAllocation
    ) external onlyGovernance {
        require(
            newIncentiveAddresses.length == newIncentiveAllocation.length,
            "the length of the addresses and the allocation should be the same"
        );
        uint256 sumcheck = 0;
        for (uint256 i = 0; i < newIncentiveAllocation.length; i++) {
            sumcheck = sumcheck.add(newIncentiveAllocation[i]);
        }
        require(sumcheck == 10**8, "the sum of the allocation should be 10**8");

        _incentiveFundAddresses = newIncentiveAddresses;
        _incentiveFundAllocationE8 = newIncentiveAllocation;

        emit LogUpdateIncentiveAddresses(newIncentiveAddresses, newIncentiveAllocation);
    }

    /**
     * @notice governanceAddress can be updated by the deployer.
     * @dev can be used only before the deployer transfers the rights of governance
     */
    function updateGovernanceAddress(address newGovernanceAddress) external onlyGovernance {
        _governanceAddress = newGovernanceAddress;

        emit LogUpdateGovernanceAddress(newGovernanceAddress);
    }

    /**
     * @notice mint tax token to the developer address up to the available amount.
     */
    function mintDeveloperFund() external {
        uint256 amount = _developerFund;
        _developerFund = 0;
        require(amount != 0, "no mintable amount");
        _mint(_developer, amount);
    }

    /**
     * @notice mint tax token to the incentive fund addresses up to the available amount.
     */
    function mintIncentiveFund() external {
        uint256 amount = _incentiveFund;
        _incentiveFund = 0;
        require(amount != 0, "no mintable amount");
        require(_incentiveFundAddresses.length != 0, "incentive fund addresses have not been set");
        for (uint256 i = 0; i < _incentiveFundAddresses.length; i++) {
            _mint(_incentiveFundAddresses[i], amount.mul(_incentiveFundAllocationE8[i]).div(10**8));
        }
    }

    /* ========== INTERNAL FUNCTIONS ========== */

    function _getMintUnit() internal view returns (uint256 asOfMintUnit) {
        uint256 totalLendValue = _totalLendValue;
        asOfMintUnit = _initialMintUnit;
        while (totalLendValue >= _halvingStartLendValue) {
            asOfMintUnit = asOfMintUnit / 2;
            totalLendValue = totalLendValue / 2;
        }
        asOfMintUnit = totalSupply() == _maxTotalSupply ? 0 : asOfMintUnit;
    }

    /* ========== CALL FUNCTIONS ========== */

    /**
     * @return governance contract address
     */
    function getGovernanceAddress() external view returns (address) {
        return _governanceAddress;
    }

    /**
     * @return developer fund address
     */
    function getDeveloperAddress() external view returns (address) {
        return _developer;
    }

    /**
     * @return lending contract address.
     */
    function getLendingAddress() external view returns (address) {
        return _lendingAddress;
    }

    /**
     * @notice get the immutable initial config values.
     */
    function getConfigs()
        external
        view
        returns (
            uint256 maxTotalSupply,
            uint256 halvingStartLendValue,
            uint256 initialMintUnit,
            uint256 developerFundRateE8,
            uint256 incentiveFundRateE8
        )
    {
        maxTotalSupply = _maxTotalSupply;
        halvingStartLendValue = _halvingStartLendValue;
        initialMintUnit = _initialMintUnit;
        developerFundRateE8 = _developerFundRateE8;
        incentiveFundRateE8 = _incentiveFundRateE8;
    }

    function getWhitelist() external view returns (address[] memory) {
        return _getWhitelist();
    }

    /**
     * @notice Get the incentive addresses and their allocation.
     */
    function getIncentiveFundAddresses()
        external
        view
        returns (
            address[] memory incentiveFundAddresses,
            uint256[] memory incentiveFundAllocationE8
        )
    {
        incentiveFundAddresses = _incentiveFundAddresses;
        incentiveFundAllocationE8 = _incentiveFundAllocationE8;
    }

    /**
     * @notice Get the current mintable amount for developer fund and incentive fund.
     */
    function getFunds() external view returns (uint256 developerFund, uint256 incentiveFund) {
        developerFund = _developerFund;
        incentiveFund = _incentiveFund;
    }

    /**
     * @notice Get the current amount to be minted per a dollar of lending.
     * @dev the amount to mint per a dollar of lending decays exponentially.
     */
    function getMintUnit() external view returns (uint256) {
        return _getMintUnit();
    }

    /**
     * @return oracle address of the erc20.
     * @dev returns zero address when the erc20 is not whitelisted.
     */
    function getOracleAddress(address tokenAddress) external view returns (address) {
        return _tokenPriceOracle[tokenAddress];
    }
}

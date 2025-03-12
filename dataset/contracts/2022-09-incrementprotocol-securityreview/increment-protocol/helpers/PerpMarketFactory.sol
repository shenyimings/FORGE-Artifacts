// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.20;

// contracts
import {DEPLOYER_SYSTEM_CONTRACT} from "../lib/era-contracts/system-contracts/contracts/Constants.sol";
import {PerpOwnable} from "../contracts/utils/PerpOwnable.sol";

// interfaces
import {AggregatorV3Interface} from "../lib/chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {IContractDeployer} from "../lib/era-contracts/system-contracts/contracts/interfaces/IContractDeployer.sol";
import {ICryptoSwap} from "../contracts/interfaces/ICryptoSwap.sol";
import {ICurveCryptoViews} from "../contracts/interfaces/ICurveCryptoViews.sol";
import {ICurveCryptoFactory} from "../contracts/interfaces/ICurveCryptoFactory.sol";
import {IClearingHouse} from "../contracts/interfaces/IClearingHouse.sol";
import {IPerpetual} from "../contracts/interfaces/IPerpetual.sol";
import {IIncreAccessControl} from "../contracts/interfaces/IIncreAccessControl.sol";

// libraries
import {SystemContractsCaller} from
    "../lib/era-contracts/system-contracts/contracts/libraries/SystemContractsCaller.sol";
import {LibMath} from "contracts/lib/LibMath.sol";

contract PerpMarketFactory {
    using LibMath for int256;

    struct DeploymentParams {
        // Perpetual params
        uint256 riskWeight;
        uint256 maxLiquidityProvided;
        uint256 twapFrequency;
        int256 sensitivity;
        uint256 maxBlockTradeAmount;
        int256 insuranceFee;
        int256 lpDebtCoef;
        uint256 lockPeriod;
        // VBase params
        uint256 heartBeat;
        uint256 gracePeriod;
        // Curve params
        uint256 a;
        uint256 gamma;
        uint256 midFee;
        uint256 outFee;
        uint256 allowedExtraProfit;
        uint256 feeGamma;
        uint256 adjustmentStep;
        uint256 adminFee;
        uint256 maHalfTime;
    }

    // Roles
    bytes32 public constant GOVERNANCE = keccak256("GOVERNANCE");
    bytes32 public constant EMERGENCY_ADMIN = keccak256("EMERGENCY_ADMIN");

    // Dependency contracts
    ICurveCryptoFactory public immutable CRYPTO_SWAP_FACTORY;
    ICurveCryptoViews public immutable CURVE_CRYPTO_VIEWS;
    IClearingHouse public immutable CLEARING_HOUSE;
    // Addresses to grant roles to
    address public immutable GOV_ADDRESS;
    address public immutable EMERGENCY_ADMIN_ADDRESS;
    // Bytecode hash for the deployed contract
    bytes32 public immutable VBASE_BYTECODE_HASH;
    bytes32 public immutable VQUOTE_BYTECODE_HASH;
    bytes32 public immutable PERP_BYTECODE_HASH;

    IPerpetual[] public markets;

    constructor(
        bytes32 _perpBytecodeHash,
        bytes32 _vBaseBytecodeHash,
        bytes32 _vQuoteBytecodeHash,
        address _cryptoSwapFactory,
        address _curveCryptoViews,
        address _clearingHouse,
        address _governance,
        address _emergencyAdmin
    ) {
        PERP_BYTECODE_HASH = _perpBytecodeHash;
        VBASE_BYTECODE_HASH = _vBaseBytecodeHash;
        VQUOTE_BYTECODE_HASH = _vQuoteBytecodeHash;
        CRYPTO_SWAP_FACTORY = ICurveCryptoFactory(_cryptoSwapFactory);
        CURVE_CRYPTO_VIEWS = ICurveCryptoViews(_curveCryptoViews);
        CLEARING_HOUSE = IClearingHouse(_clearingHouse);
        GOV_ADDRESS = _governance;
        EMERGENCY_ADMIN_ADDRESS = _emergencyAdmin;
    }

    function getNumMarkets() external view returns (uint256) {
        return markets.length;
    }

    function deployNewMarket(
        address oracle,
        address uptimeFeed,
        string memory vBaseName,
        string memory vBaseSymbol,
        string memory poolName,
        string memory poolSymbol,
        DeploymentParams memory params
    ) external returns (IPerpetual) {
        // set aggregator
        AggregatorV3Interface baseOracle = AggregatorV3Interface(oracle);
        AggregatorV3Interface sequencerUptimeFeed = AggregatorV3Interface(uptimeFeed);

        // deploy virtual tokens
        address vBaseAddress =
            _deployVBase(vBaseName, vBaseSymbol, baseOracle, sequencerUptimeFeed, params.heartBeat, params.gracePeriod);
        address vQuoteAddress = _deployVQuote("vUSD quote token", "vUSD");

        // deploy cryptoswap
        (, int256 answer,,,) = baseOracle.latestRoundData();
        uint8 decimals = baseOracle.decimals();
        uint256 initialPrice = answer.toUint256() * (10 ** (18 - decimals));
        ICryptoSwap cryptoSwap = ICryptoSwap(
            CRYPTO_SWAP_FACTORY.deploy_pool(
                poolName,
                poolSymbol,
                [vQuoteAddress, vBaseAddress],
                params.a,
                params.gamma,
                params.midFee,
                params.outFee,
                params.allowedExtraProfit,
                params.feeGamma,
                params.adjustmentStep,
                params.adminFee,
                params.maHalfTime,
                initialPrice
            )
        );

        // deploy perpetual
        address perpAddress = _deployPerpetual(vBaseAddress, vQuoteAddress, cryptoSwap, params);
        IPerpetual perp = IPerpetual(perpAddress);
        PerpOwnable(vBaseAddress).transferPerpOwner(address(perp));
        PerpOwnable(vQuoteAddress).transferPerpOwner(address(perp));

        // grant roles
        IIncreAccessControl(perpAddress).grantRole(GOVERNANCE, GOV_ADDRESS);
        IIncreAccessControl(perpAddress).grantRole(EMERGENCY_ADMIN, EMERGENCY_ADMIN_ADDRESS);

        // renounce roles for this contract
        IIncreAccessControl(perpAddress).renounceRole(GOVERNANCE, address(this));
        IIncreAccessControl(perpAddress).renounceRole(EMERGENCY_ADMIN, address(this));

        // allowlist the new market in the clearing house
        CLEARING_HOUSE.allowListPerpetual(perp);

        markets.push(perp);
        return perp;
    }

    function _deployVBase(
        string memory name,
        string memory symbol,
        AggregatorV3Interface baseOracle,
        AggregatorV3Interface sequencerUptimeFeed,
        uint256 heartbeat,
        uint256 gracePeriod
    ) internal returns (address vBaseAddress) {
        (bool success, bytes memory returnData) = SystemContractsCaller.systemCallWithReturndata(
            uint32(gasleft()),
            address(DEPLOYER_SYSTEM_CONTRACT),
            uint128(0),
            abi.encodeCall(
                DEPLOYER_SYSTEM_CONTRACT.create2Account,
                (
                    bytes32(0),
                    VBASE_BYTECODE_HASH,
                    abi.encode(name, symbol, baseOracle, heartbeat, sequencerUptimeFeed, gracePeriod),
                    IContractDeployer.AccountAbstractionVersion.Version1
                )
            )
        );
        require(success, "VBase deployment failed");
        (vBaseAddress) = abi.decode(returnData, (address));
    }

    function _deployVQuote(string memory name, string memory symbol) internal returns (address vQuoteAddress) {
        (bool success, bytes memory returnData) = SystemContractsCaller.systemCallWithReturndata(
            uint32(gasleft()),
            address(DEPLOYER_SYSTEM_CONTRACT),
            uint128(0),
            abi.encodeCall(
                DEPLOYER_SYSTEM_CONTRACT.create2Account,
                (
                    bytes32(0),
                    VQUOTE_BYTECODE_HASH,
                    abi.encode(name, symbol),
                    IContractDeployer.AccountAbstractionVersion.Version1
                )
            )
        );
        require(success, "VQuote deployment failed");
        (vQuoteAddress) = abi.decode(returnData, (address));
    }

    function _deployPerpetual(address vBase, address vQuote, ICryptoSwap cryptoSwap, DeploymentParams memory params)
        internal
        returns (address perpAddress)
    {
        (bool success, bytes memory returnData) = SystemContractsCaller.systemCallWithReturndata(
            uint32(gasleft()),
            address(DEPLOYER_SYSTEM_CONTRACT),
            uint128(0),
            abi.encodeCall(
                DEPLOYER_SYSTEM_CONTRACT.create2Account,
                (
                    bytes32(0),
                    PERP_BYTECODE_HASH,
                    abi.encode(
                        vBase,
                        vQuote,
                        cryptoSwap,
                        CLEARING_HOUSE,
                        CURVE_CRYPTO_VIEWS,
                        false,
                        IPerpetual.PerpetualParams(
                            params.riskWeight,
                            params.maxLiquidityProvided,
                            params.twapFrequency,
                            params.sensitivity,
                            params.maxBlockTradeAmount,
                            params.insuranceFee,
                            params.lpDebtCoef,
                            params.lockPeriod
                        )
                        ),
                    IContractDeployer.AccountAbstractionVersion.Version1
                )
            )
        );
        require(success, "Perpetual deployment failed");
        (perpAddress) = abi.decode(returnData, (address));
    }
}

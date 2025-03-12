// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../../interfaces/tokenomics/IInitialDistribution.sol";
import "../../interfaces/tokenomics/ICNCToken.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../../libraries/ScaledMath.sol";
import "../../libraries/MerkleProof.sol";

contract InitialDistribution is IInitialDistribution, Ownable {
    using ScaledMath for uint256;
    using SafeERC20 for IERC20;
    using MerkleProof for MerkleProof.Proof;

    uint256 internal constant TOTAL_AMOUNT = 0.3e18 * 10_000_000;
    uint256 internal constant MIN_DURATION = 1 days;

    uint256 public constant ETH_PER_TRANCHE = 14e18;
    uint256 public constant WHITELIST_DURATION = 3 hours;
    uint256 internal constant INFLATION_SCALE = 1e18;
    uint256 internal constant REDUCTION_RATIO = 0.53333e18;
    uint256 internal constant INITIAL_TRANCHE = 0.14e18 * 10_000_000;

    address public immutable token;
    address public immutable treasury;
    uint256 public immutable maxPerUser;
    bytes32 public immutable merkleRoot;
    uint256 public startedAt;
    uint256 public endedAt;

    uint256 public exchangeRate;
    uint256 public currentTrancheSize;
    uint256 public lastReductionAmount;
    uint256 public totalMinted;

    mapping(address => uint256) public apedPerUser;

    constructor(address _token, address _treasury, uint256 _maxPerUser, bytes32 _merkleRoot) {
        token = _token;
        treasury = _treasury;
        exchangeRate = INITIAL_TRANCHE.divDown(ETH_PER_TRANCHE) * INFLATION_SCALE;
        currentTrancheSize = INITIAL_TRANCHE;
        maxPerUser = _maxPerUser;
        merkleRoot = _merkleRoot;
    }

    /// @notice Query the amount of tokens one would receive for an amount of ETH
    function getAmountForDeposit(uint256 depositAmount) public view returns (uint256) {
        return
            _getAmountForDeposit(
                depositAmount,
                exchangeRate,
                currentTrancheSize,
                getLeftInTranche()
            );
    }

    /// @return returns a default minimum amount of CNC token to be received
    /// for a given ETH amount
    /// this will compute an amount with a single tranch devation
    function getDefaultMinOutput(uint256 depositAmount) external view returns (uint256) {
        uint256 initialExchangeRate = exchangeRate.mulDown(REDUCTION_RATIO);
        uint256 _currentTrancheSize = currentTrancheSize;
        uint256 trancheSize = _currentTrancheSize.mulDown(REDUCTION_RATIO);
        uint256 extraMinted = getAmountForDeposit(ETH_PER_TRANCHE);
        uint256 leftInTranche = (lastReductionAmount + _currentTrancheSize) +
            trancheSize -
            (totalMinted + extraMinted);
        return _getAmountForDeposit(depositAmount, initialExchangeRate, trancheSize, leftInTranche);
    }

    function _getAmountForDeposit(
        uint256 depositAmount,
        uint256 initialExchangeRate,
        uint256 initialTrancheSize,
        uint256 leftInTranche
    ) internal pure returns (uint256) {
        uint256 amountAtRate = depositAmount.mulDown(initialExchangeRate) / INFLATION_SCALE;
        if (amountAtRate <= leftInTranche) {
            return amountAtRate;
        }

        uint256 receiveAmount;
        uint256 amountSatisfied;
        uint256 tempTrancheSize = initialTrancheSize;
        uint256 tempExchangeRate = initialExchangeRate;

        while (amountSatisfied <= depositAmount) {
            if (amountAtRate >= leftInTranche) {
                amountSatisfied += (leftInTranche * INFLATION_SCALE).divDown(tempExchangeRate);
                receiveAmount += leftInTranche;
            } else {
                receiveAmount += amountAtRate;
                break;
            }
            tempExchangeRate = tempExchangeRate.mulDown(REDUCTION_RATIO);
            tempTrancheSize = tempTrancheSize.mulDown(REDUCTION_RATIO);
            amountAtRate =
                (depositAmount - amountSatisfied).mulDown(tempExchangeRate) /
                INFLATION_SCALE;
            leftInTranche = tempTrancheSize;
        }
        return receiveAmount;
    }

    function getLeftInTranche() public view override returns (uint256) {
        return lastReductionAmount + currentTrancheSize - totalMinted;
    }

    function ape(
        uint256 minOutputAmount,
        MerkleProof.Proof calldata proof
    ) external payable override {
        if (startedAt + WHITELIST_DURATION >= block.timestamp) {
            bytes32 node = keccak256(abi.encodePacked(msg.sender));
            require(proof.isValid(node, merkleRoot), "invalid proof");
        }
        _ape(minOutputAmount);
    }

    // @notice Apes tokens for ETH. The amount is determined by the msg.value
    function ape(uint256 minOutputAmount) external payable override {
        require(startedAt + WHITELIST_DURATION <= block.timestamp, "whitelist is active");
        _ape(minOutputAmount);
    }

    function _ape(uint256 minOutputAmount) internal {
        require(msg.value > 0, "nothing to ape");
        require(endedAt == 0, "distribution has ended");
        require(startedAt != 0, "distribution has not yet started");
        require(exchangeRate > 1e18, "distribution has exceeded max exchange rate");

        uint256 aped = apedPerUser[msg.sender];
        require(aped + msg.value <= maxPerUser, "cannot ape more than 1 ETH");
        apedPerUser[msg.sender] = aped + msg.value;

        uint256 amountAtRate = (msg.value).mulDown(exchangeRate) / INFLATION_SCALE;
        uint256 leftInTranche = getLeftInTranche();
        if (amountAtRate <= leftInTranche) {
            require(amountAtRate >= minOutputAmount, "too much slippage");
            totalMinted += amountAtRate;
            IERC20(token).safeTransfer(msg.sender, amountAtRate);
            (bool sent_, ) = payable(treasury).call{value: msg.value, gas: 20000}("");
            require(sent_, "failed to send to treasury");
            emit TokenDistributed(msg.sender, amountAtRate, msg.value);
            return;
        }

        uint256 receiveAmount;
        uint256 amountSatisfied;

        while (amountSatisfied <= msg.value) {
            if (amountAtRate >= leftInTranche) {
                amountSatisfied += (leftInTranche * INFLATION_SCALE).divDown(exchangeRate);
                receiveAmount += leftInTranche;
            } else {
                receiveAmount += amountAtRate;
                break;
            }
            lastReductionAmount = lastReductionAmount + currentTrancheSize;
            exchangeRate = exchangeRate.mulDown(REDUCTION_RATIO);
            currentTrancheSize = currentTrancheSize.mulDown(REDUCTION_RATIO);
            amountAtRate = (msg.value - amountSatisfied).mulDown(exchangeRate) / INFLATION_SCALE;
            leftInTranche = currentTrancheSize;
        }
        totalMinted += receiveAmount;

        require(receiveAmount >= minOutputAmount, "too much slippage");
        (bool sent, ) = payable(treasury).call{value: msg.value, gas: 20000}("");
        require(sent, "failed to send to treasury");
        IERC20(token).safeTransfer(msg.sender, receiveAmount);
        emit TokenDistributed(msg.sender, receiveAmount, msg.value);
    }

    function start() external override onlyOwner {
        require(startedAt == 0, "distribution already started");
        startedAt = block.timestamp;
        emit DistributonStarted();
    }

    function end() external override onlyOwner {
        require(block.timestamp > startedAt + MIN_DURATION);
        require(endedAt == 0, "distribution already ended");
        IERC20 _token = IERC20(token);
        _token.safeTransfer(treasury, _token.balanceOf(address(this)));
        endedAt = block.timestamp;
        emit DistributonEnded();
    }
}

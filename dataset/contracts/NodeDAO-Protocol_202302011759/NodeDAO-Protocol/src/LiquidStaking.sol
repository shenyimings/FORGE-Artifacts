// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import "openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/security/PausableUpgradeable.sol";
import "src/interfaces/INodeOperatorsRegistry.sol";
import "src/interfaces/INETH.sol";
import "src/interfaces/IVNFT.sol";
import "src/interfaces/IDepositContract.sol";
import "src/interfaces/IBeaconOracle.sol";
import "src/interfaces/IELVault.sol";

contract LiquidStaking is
    Initializable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable,
    OwnableUpgradeable,
    PausableUpgradeable
{
    IDepositContract public depositContract;

    bytes public liquidStakingWithdrawalCredentials;

    uint256 public depositFeeRate; // deposit fee rate
    uint256 public unstakeFeeRate; // unstake fee rate
    uint256 public constant totalBasisPoints = 10000;

    uint256 public constant DEPOSIT_SIZE = 32 ether;

    INodeOperatorsRegistry public nodeOperatorRegistryContract;

    INETH public nETHContract;

    IVNFT public vNFTContract;

    IBeaconOracle public beaconOracleContract;

    uint256[] private _liquidNfts; // The validator tokenid owned by the stake pool
    mapping(uint256 => uint256[]) private _operatorNfts;
    mapping(uint256 => bool) private _liquidUserNfts; // The nft purchased from the staking pool using neth

    uint256 public unstakePoolSize; // nETH unstake pool size
    uint256 public unstakePoolDrawnRate;
    uint256 public unstakePoolBalances;

    mapping(uint256 => uint256) public operatorPoolBalances; // operator's private stake pool, key is operator_id

    uint256 public wrapOperator; // When buying nft next time, sell the operator id of nft
    uint256 public nftWrapNonce;

    // dao address
    address public dao;
    // dao treasury address
    address public daoVaultAddress;

    modifier onlyDao() {
        require(msg.sender == dao, "AUTH_FAILED");
        _;
    }

    event EthStake(address indexed from, uint256 amount, uint256 amountOut, address indexed _referral);
    event EthUnstake(address indexed from, uint256 amount, uint256 amountOut);
    event NftStake(address indexed from, uint256 count, address indexed _referral);
    event Eth32Deposit(bytes _pubkey, bytes _withdrawal, address _owner);
    event ValidatorRegistered(uint256 operator, uint256 tokenId);
    event NftWrap(uint256 tokenId, uint256 operatorId, uint256 value, uint256 amountOut);
    event NftUnwrap(uint256 tokenId, uint256 operatorId, uint256 value, uint256 amountOut);
    event OperatorClaimRewards(uint256 operatorId, uint256 rewards);
    event ClaimRewardsToUnstakePool(uint256 operatorId, uint256 rewards);
    event stakeETHToUnstakePool(uint256 operatorId, uint256 amount);
    event UserClaimRewards(uint256 operatorId, uint256 rewards);
    event Transferred(address _to, uint256 _amount);

    function initialize(
        address _dao,
        address _daoVaultAddress,
        bytes memory withdrawalCreds,
        address _nodeOperatorRegistryContractAddress,
        address _nETHContractAddress,
        address _nVNFTContractAddress,
        address _beaconOracleContractAddress,
        address _depositContractAddress
    ) external initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        dao = _dao;
        daoVaultAddress = _daoVaultAddress;

        liquidStakingWithdrawalCredentials = withdrawalCreds;

        depositContract = IDepositContract(_depositContractAddress);
        nodeOperatorRegistryContract = INodeOperatorsRegistry(_nodeOperatorRegistryContractAddress);

        nETHContract = INETH(_nETHContractAddress);

        vNFTContract = IVNFT(_nVNFTContractAddress);

        beaconOracleContract = IBeaconOracle(_beaconOracleContractAddress);

        unstakeFeeRate = 5;
        unstakePoolSize = 1000 ether;
        wrapOperator = 1;
        unstakePoolDrawnRate = 1000;
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    function stakeETH(address _referral, uint256 _operatorId) external payable nonReentrant {
        require(msg.value >= 1000 wei, "Stake amount must be minimum  1000 wei");
        require(_referral != address(0), "Referral address must be provided");
        require(nodeOperatorRegistryContract.isTrustedOperator(_operatorId), "The operator is not trusted");

        uint256 depositFeeAmount;
        uint256 depositPoolAmount;
        if (depositFeeRate == 0) {
            depositPoolAmount = msg.value;
        } else {
            depositFeeAmount = msg.value * depositFeeRate / totalBasisPoints;
            depositPoolAmount = msg.value - depositFeeAmount;
            transfer(depositFeeAmount, daoVaultAddress);
        }

        // 1. Convert depositAmount according to the exchange rate of nETH
        // 2. Mint nETH
        uint256 amountOut = _getNethOut(depositPoolAmount, depositFeeAmount);
        nETHContract.whiteListMint(amountOut, msg.sender);

        if (unstakePoolBalances < unstakePoolSize) {
            uint256 drawnAmount = depositPoolAmount * unstakePoolDrawnRate / totalBasisPoints;
            if (unstakePoolBalances + drawnAmount > unstakePoolSize) {
                drawnAmount = unstakePoolBalances + drawnAmount - unstakePoolSize;
            }

            depositPoolAmount -= drawnAmount;
            unstakePoolBalances += drawnAmount;
            emit stakeETHToUnstakePool(_operatorId, drawnAmount);
        }

        operatorPoolBalances[_operatorId] += depositPoolAmount;

        emit EthStake(msg.sender, msg.value, amountOut, _referral);
    }

    //1. Burn the user's nETH
    //2. Transfer eth to the user
    function unstakeETH(uint256 amount) external nonReentrant {
        uint256 amountOut = getEthOut(amount);
        require(unstakePoolBalances >= amountOut, "UNSTAKE_POOL_INSUFFICIENT_BALANCE");

        nETHContract.whiteListBurn(amount, msg.sender);
        unstakePoolBalances -= amountOut;

        uint256 userAmount;
        uint256 feeAmount;
        if (unstakeFeeRate == 0) {
            userAmount = amountOut;
        } else {
            feeAmount = amountOut * unstakeFeeRate / totalBasisPoints;
            userAmount = amountOut - feeAmount;
            transfer(feeAmount, daoVaultAddress);
        }

        transfer(amountOut, msg.sender);

        emit EthUnstake(msg.sender, amount, amountOut);
    }

    //1. depost
    //2. _operatorId must be a trusted operator
    function stakeNFT(address _referral, uint256 _operatorId) external payable nonReentrant {
        require(nodeOperatorRegistryContract.isTrustedOperator(_operatorId), "The operator is not trusted");
        require(msg.value % DEPOSIT_SIZE == 0, "Incorrect Ether amount provided");

        uint256 amountOut = _getNethOut(msg.value, 0);
        nETHContract.whiteListMint(amountOut, address(this));

        uint256 mintNftsCount = msg.value / DEPOSIT_SIZE;
        for (uint256 i = 0; i < mintNftsCount; i++) {
            uint256 tokenId;
            (, tokenId) = vNFTContract.whiteListMint(bytes(""), msg.sender, _operatorId);
            _liquidNfts.push(tokenId);
            _operatorNfts[_operatorId].push(tokenId);
            address vaultContractAddress = nodeOperatorRegistryContract.getNodeOperatorVaultContract(_operatorId);
            IELVault(vaultContractAddress).setUserNft(tokenId, block.number);
        }

        emit NftStake(msg.sender, mintNftsCount, _referral);
    }

    //1. Check whether msg.sender is the controllerAddress of the operator
    //2. Check if operator_id is trusted
    //3. precheck, need to add check withdrawalCredentials must be set by the stake pool
    //4. signercheck
    //5. depost
    //6. operatorPoolBalances[_operatorId] = operatorPoolBalances[_operatorId] -depositAmount;
    //7. mint nft, minting nft, stored in the stake pool contract, can no longer mint neth, because minting has been completed when the user deposits
    //8. Update _liquidNfts
    function registerValidator(
        bytes[] calldata pubkeys,
        bytes[] calldata signatures,
        bytes32[] calldata depositDataRoots
    ) external nonReentrant {
        uint256 operatorId = nodeOperatorRegistryContract.isTrustedOperator(msg.sender);
        require(operatorId != 0, "msg.sender must be the controllerAddress of the trusted operator");
        require(getOperatorPoolEtherMultiple(operatorId) >= pubkeys.length, "Insufficient balance");

        _settle(operatorId);

        for (uint256 i = 0; i < pubkeys.length; i++) {
            _stakeAndMint(operatorId, pubkeys[i], signatures[i], depositDataRoots[i]);
        }

        operatorPoolBalances[operatorId] -= DEPOSIT_SIZE * pubkeys.length;
    }

    function _stakeAndMint(uint256 operatorId, bytes calldata pubkey, bytes calldata signature, bytes32 depositDataRoot)
        internal
    {
        depositContract.deposit{value: 32 ether}(pubkey, liquidStakingWithdrawalCredentials, signature, depositDataRoot);

        // mint nft
        bool isMint;
        uint256 tokenId;
        (isMint, tokenId) = vNFTContract.whiteListMint(pubkey, address(this), operatorId);
        if (isMint) {
            _liquidNfts.push(tokenId);
            _operatorNfts[operatorId].push(tokenId);
        }

        emit ValidatorRegistered(operatorId, tokenId);
    }

    /**
     * @notice Allows transfer funds of 32 ETH to the ETH2 Official Deposit Contract
     */
    //slither-disable-next-line reentrancy-events
    function deposit(bytes calldata data) private {
        bytes calldata pubkey = data[16:64];
        bytes calldata withdrawalCredentials = data[64:96];
        bytes calldata signature = data[96:192];
        bytes32 depositDataRoot = bytes32(data[192:224]);

        depositContract.deposit{value: 32 ether}(pubkey, withdrawalCredentials, signature, depositDataRoot);

        emit Eth32Deposit(pubkey, withdrawalCredentials, msg.sender);
    }

    function unstakeNFT(bytes[] calldata data) public nonReentrant returns (bool) {
        return data.length == 0;
    }

    //wrap neth to nft
    //1. Check whether the wrapOperator corresponding to the token id is correct
    //2. Check if the value matches the oracle
    //3. Check if the neth balance is satisfied -not required
    //4. Transfer user neth to the stake pool
    //5. Trigger the operator's claim once, and transfer the nft to the user
    //6. Increment wrapOperator loop
    //7. Record _liquidUserNfts as true
    //8. Set the vault contract setUserNft to block.number
    function wrapNFT(uint256 tokenId, bytes32[] memory proof, uint256 value) external nonReentrant {
        uint256 operatorId = vNFTContract.operatorOf(tokenId);
        require(operatorId == wrapOperator, "The selected token id does not belong to the operator being sold");

        uint256 amountOut = _getNethOut(value, 0);

        bytes memory pubkey = vNFTContract.validatorOf(tokenId);
        bool success = beaconOracleContract.verifyNftValue(proof, pubkey, value, tokenId);
        require(success, "verifyNftValue fail");

        success = nETHContract.transferFrom(msg.sender, address(this), amountOut);
        require(success, "Failed to transfer neth");

        _settle(operatorId);
        claimRewardsOfOperator(operatorId);

        vNFTContract.safeTransferFrom(address(this), msg.sender, tokenId);

        if (wrapOperator == nodeOperatorRegistryContract.getNodeOperatorsCount()) {
            wrapOperator = 1;
        } else {
            wrapOperator = wrapOperator + 1;
        }

        _liquidUserNfts[tokenId] = true;

        address vaultContractAddress = nodeOperatorRegistryContract.getNodeOperatorVaultContract(operatorId);
        IELVault(vaultContractAddress).setUserNft(tokenId, block.number);
        nftWrapNonce = nftWrapNonce + 1;

        emit NftWrap(tokenId, operatorId, value, amountOut);
    }

    //unwrap nft to neth
    //1. Check if the originator holds a token_id -not required
    //2. Check if the value matches the oracle
    //3. Claim income for the user, and transfer the user's nft to the stake pool
    //4. Transfer neth to the user
    //5. Set the vault contract setUserNft to 0
    function unwrapNFT(uint256 tokenId, bytes32[] memory proof, uint256 value) external nonReentrant {
        uint256 operatorId = vNFTContract.operatorOf(tokenId);

        bool trusted;
        address vaultContractAddress;
        (trusted,,,, vaultContractAddress) = nodeOperatorRegistryContract.getNodeOperator(operatorId, false);
        require(trusted, "permission denied");

        bytes memory pubkey = vNFTContract.validatorOf(tokenId);
        bool success = beaconOracleContract.verifyNftValue(proof, pubkey, value, tokenId);
        require(success, "verifyNftValue fail");

        uint256 amountOut = _getNethOut(value, 0);

        _liquidUserNfts[tokenId] = false;

        _settle(operatorId);
        claimRewardsOfUser(tokenId);

        vNFTContract.safeTransferFrom(msg.sender, address(this), tokenId);

        success = nETHContract.transferFrom(msg.sender, address(this), amountOut);
        require(success, "Failed to transfer neth");

        IELVault(vaultContractAddress).setUserNft(tokenId, 0);
        nftWrapNonce = nftWrapNonce + 1;

        emit NftUnwrap(tokenId, operatorId, value, amountOut);
    }

    //1. claim income operatorPoolBalances
    //2. Earnings are settled setLiquidStakingGasHeight
    function batchClaimRewardsOfOperator(uint256[] memory operatorIds) public {
        for (uint256 i = 0; i < operatorIds.length; i++) {
            address vaultContractAddress = nodeOperatorRegistryContract.getNodeOperatorVaultContract(operatorIds[i]);
            IELVault(vaultContractAddress).settle();

            uint256 nftRewards = IELVault(vaultContractAddress).claimRewardsOfLiquidStaking();
            IELVault(vaultContractAddress).setLiquidStakingGasHeight(block.number);

            if (unstakePoolBalances < unstakePoolSize) {
                if (unstakePoolBalances + nftRewards > unstakePoolSize) {
                    uint256 operatorFund = unstakePoolBalances + nftRewards - unstakePoolSize;
                    unstakePoolBalances = unstakePoolSize;
                    operatorPoolBalances[operatorIds[i]] += operatorFund;
                    emit ClaimRewardsToUnstakePool(operatorIds[i], nftRewards - operatorFund);
                    emit OperatorClaimRewards(operatorIds[i], operatorFund);
                } else {
                    unstakePoolBalances += nftRewards;
                    emit ClaimRewardsToUnstakePool(operatorIds[i], nftRewards);
                }
            } else {
                operatorPoolBalances[operatorIds[i]] += nftRewards;
                emit OperatorClaimRewards(operatorIds[i], nftRewards);
            }
        }
    }

    //1. claim income operatorPoolBalances
    //2. Earnings are settled setLiquidStakingGasHeight
    function claimRewardsOfOperator(uint256 operatorId) public {
        address vaultContractAddress = nodeOperatorRegistryContract.getNodeOperatorVaultContract(operatorId);
        IELVault(vaultContractAddress).settle();

        uint256 nftRewards = IELVault(vaultContractAddress).claimRewardsOfLiquidStaking();
        IELVault(vaultContractAddress).setLiquidStakingGasHeight(block.number);

        if (unstakePoolBalances < unstakePoolSize) {
            if (unstakePoolBalances + nftRewards > unstakePoolSize) {
                uint256 operatorFund = unstakePoolBalances + nftRewards - unstakePoolSize;
                unstakePoolBalances = unstakePoolSize;
                operatorPoolBalances[operatorId] += operatorFund;
                emit ClaimRewardsToUnstakePool(operatorId, nftRewards - operatorFund);
                emit OperatorClaimRewards(operatorId, operatorFund);
            } else {
                unstakePoolBalances += nftRewards;
                emit ClaimRewardsToUnstakePool(operatorId, nftRewards);
            }
        } else {
            operatorPoolBalances[operatorId] += nftRewards;
            emit OperatorClaimRewards(operatorId, nftRewards);
        }
    }

    function claimRewardsOfUser(uint256 tokenId) public {
        uint256 operatorId = vNFTContract.operatorOf(tokenId);
        address vaultContractAddress = nodeOperatorRegistryContract.getNodeOperatorVaultContract(operatorId);
        IELVault(vaultContractAddress).settle();

        uint256 nftRewards = IELVault(vaultContractAddress).claimRewardsOfUser(tokenId);

        emit UserClaimRewards(operatorId, nftRewards);
    }

    function _settle(uint256 operatorId) internal {
        address vaultContractAddress = nodeOperatorRegistryContract.getNodeOperatorVaultContract(operatorId);
        IELVault(vaultContractAddress).settle();
    }

    function getTotalEthValue() public view returns (uint256) {
        uint256 beaconBalance = beaconOracleContract.getBeaconBalances();
        return beaconBalance + address(this).balance;
    }

    function getEthOut(uint256 _nethAmountIn) public view returns (uint256) {
        uint256 totalEth = getTotalEthValue();
        uint256 nethSupply = nETHContract.totalSupply();
        if (nethSupply == 0) {
            return _nethAmountIn;
        }

        return _nethAmountIn * (totalEth) / (nethSupply);
    }

    function _getNethOut(uint256 _ethAmountIn, uint256 _fee) internal returns (uint256) {
        uint256 totalEth = getTotalEthValue() - (msg.value - _fee);
        uint256 nethSupply = nETHContract.totalSupply();
        if (nethSupply == 0) {
            return _ethAmountIn;
        }
        require(totalEth > 0, "Cannot calculate nETH token amount while balance is zero");
        return _ethAmountIn * (nethSupply) / (totalEth);
    }

    function getNethOut(uint256 _ethAmountIn) public view returns (uint256) {
        uint256 totalEth = getTotalEthValue();
        uint256 nethSupply = nETHContract.totalSupply();
        if (nethSupply == 0) {
            return _ethAmountIn;
        }
        require(totalEth > 0, "Cannot calculate nETH token amount while balance is zero");
        return _ethAmountIn * (nethSupply) / (totalEth);
    }

    function getExchangeRate() external view returns (uint256) {
        return getEthOut(1 ether);
    }

    // The total number of validators currently owned by the stake pool
    function getLiquidValidatorsCount() public view returns (uint256) {
        return getLiquidNfts().length;
    }

    // Validators currently owned by the stake pool
    function getLiquidNfts() public view returns (uint256[] memory) {
        uint256 nftCount;
        uint256[] memory liquidNfts;
        uint256 i;
        for (i = 0; i < _liquidNfts.length; i++) {
            uint256 tokenId = _liquidNfts[i];
            if (_liquidUserNfts[tokenId]) {
                nftCount += 1;
            }
        }

        liquidNfts = new uint256[] (nftCount);
        for (i = 0; i < _liquidNfts.length; i++) {
            uint256 tokenId = _liquidNfts[i];
            if (_liquidUserNfts[tokenId]) {
                liquidNfts[i] = tokenId;
            }
        }

        return liquidNfts;
    }

    function getOperatorNfts(uint256 operatorId) public view returns (uint256[] memory) {
        uint256 nftCount;
        uint256[] memory operatorNfts;

        uint256[] memory nfts = _operatorNfts[operatorId];
        uint256 i;
        for (i = 0; i < nfts.length; i++) {
            uint256 tokenId = nfts[i];
            if (_liquidUserNfts[tokenId]) {
                nftCount += 1;
            }
        }

        operatorNfts = new uint256[] (nftCount);
        for (i = 0; i < nfts.length; i++) {
            uint256 tokenId = nfts[i];
            if (_liquidUserNfts[tokenId]) {
                operatorNfts[i] = tokenId;
            }
        }

        return operatorNfts;
    }

    /**
     * @notice set dao vault address
     */
    function setDaoAddress(address _dao) external onlyDao {
        dao = _dao;
    }

    function setUnstakePoolSize(uint256 _unstakePoolSize) public onlyDao {
        unstakePoolSize = _unstakePoolSize;
    }

    function setDepositFeeRate(uint256 _feeRate) external onlyDao {
        require(_feeRate < totalBasisPoints, "cannot be 100%");
        depositFeeRate = _feeRate;
    }

    function setUnstakeFeeRate(uint256 _feeRate) external onlyDao {
        require(_feeRate < totalBasisPoints, "cannot be 100%");
        unstakeFeeRate = _feeRate;
    }

    function setLiquidStakingWithdrawalCredentials(bytes memory _liquidStakingWithdrawalCredentials) external onlyDao {
        liquidStakingWithdrawalCredentials = _liquidStakingWithdrawalCredentials;
    }

    function transfer(uint256 amount, address to) private {
        require(to != address(0), "Recipient address provided invalid");
        payable(to).transfer(amount);
        emit Transferred(to, amount);
    }

    function getOperatorPoolEtherMultiple(uint256 operator) internal view returns (uint256) {
        return operatorPoolBalances[operator] / 32 ether;
    }
}

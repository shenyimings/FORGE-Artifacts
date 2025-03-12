// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "./Opportunity.sol";
import "../libraries/UniERC20Upgradeable.sol";
import "../interfaces/IUniswapV2Router02.sol";
import "../interfaces/IPancakeMasterChefV2.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";

/**
 * @title Pancake Opportunities
 * @notice The contract is used to add/remove liquidity in pools of Pancake and
 * stake/unstake the corresponding LP token
 * currently supported pools: cake-bnb, cake-usdt, cake-busd, busd-bnb
 */
contract PancakeOpportunity is Opportunity, ReentrancyGuardUpgradeable {
    using UniERC20Upgradeable for IERC20Upgradeable;

    address public swapContract;
    IUniswapV2Router02 public router;
    IPancakeMasterChefV2 public pancakeMasterChefV2;
    uint256 pId;

    address[] private userAddressList;

    struct UserInfo {
        uint256 lpBalance;
        uint256 distributedReward;
        bool exist;
    }
    /**
     * @dev A struct containing parameters needed to calculate fees
     * @member feeTo The address of recipient of the fees
     * @member addLiquidityFee The initial fee of Add Liquidity step
     * @member removeLiquidityFee The initial fee of Remove Liquidity step
     * @member stakeFee The initial fee of Stake step
     * @member unstakeFee The initial fee of Unstake step
     */
    struct FeeStruct {
        address payable feeTo;
        uint256 addLiquidityFee;
        uint256 removeLiquidityFee;
        uint256 stakeFee;
        uint256 unstakeFee;
    }

    mapping(address => UserInfo) public userInfo;

    IERC20Upgradeable public rewardToken;

    /**
     * @dev The contract constructor
     * @param _tokenA The address of the A token
     * @param _tokenB The address of the B token
     * @param _rewardToken The address of the reward token
     * @param _pair The address of the pair
     * @param feeStruct Parameters needed for fee
     * @param _swapContract The address of the CrowdSwap Swap Contract
     * @param _router The address of the PancakeSwap: Router v2 Contract
     * @param _pancakeMasterChefV2 The address of the Stake LP Contract
     * @param _pId The id of the pool on the PancakeSwap
     */
    function initialize(
        address _tokenA,
        address _tokenB,
        address _rewardToken,
        address _pair,
        FeeStruct memory feeStruct,
        address _swapContract,
        address _router,
        address _pancakeMasterChefV2,
        uint256 _pId
    ) public initializer {
        Opportunity._initializeContracts(_tokenA, _tokenB, _pair);
        Opportunity._initializeFees(
            feeStruct.feeTo,
            feeStruct.addLiquidityFee,
            feeStruct.removeLiquidityFee,
            feeStruct.stakeFee,
            feeStruct.unstakeFee
        );
        swapContract = _swapContract;
        router = IUniswapV2Router02(_router);
        pancakeMasterChefV2 = IPancakeMasterChefV2(_pancakeMasterChefV2);
        pId = _pId;
        rewardToken = IERC20Upgradeable(_rewardToken);
    }

    modifier updateRewards() {
        IPancakeMasterChefV2 _pancakeMasterChefV2 = pancakeMasterChefV2;
        uint256 _beforeRewards = rewardToken.balanceOf(address(this));
        _pancakeMasterChefV2.deposit(pId, 0);
        uint256 _afterRewards = rewardToken.balanceOf(address(this));
        uint256 _newRewards = _afterRewards - _beforeRewards;
        (uint256 amount, , ) = _pancakeMasterChefV2.userInfo(
            pId,
            address(this)
        );
        for (uint256 i = 0; i < userAddressList.length; i++) {
            address userAddress = userAddressList[i];
            userInfo[userAddress].distributedReward +=
                (_newRewards * userInfo[userAddress].lpBalance) /
                amount;
        }
        _;
    }

    function setSwapContract(address _address) external onlyOwner {
        require(_address != address(0), "oe12");
        swapContract = _address;
    }

    function setRouter(address _address) external onlyOwner {
        require(_address != address(0), "oe12");
        router = IUniswapV2Router02(_address);
    }

    function setMasterChefV2(address _address) external onlyOwner {
        require(_address != address(0), "oe12");
        pancakeMasterChefV2 = IPancakeMasterChefV2(_address);
    }

    function setPId(uint256 _pId) external onlyOwner {
        pId = _pId;
    }

    function setRewardToken(address _rewardToken) external onlyOwner {
        require(_rewardToken != address(0), "oe12");
        rewardToken = IERC20Upgradeable(_rewardToken);
    }

    function getUserInfo(address _userAddress)
        external
        view
        returns (uint256, uint256)
    {
        require(userInfo[_userAddress].exist, "oe16");
        uint256 _lpBalance = userInfo[_userAddress].lpBalance;
        uint256 _rewards = userInfo[_userAddress].distributedReward;
        IPancakeMasterChefV2 _pancakeMasterChefV2 = pancakeMasterChefV2;
        uint256 _rewardsInPancake = _pancakeMasterChefV2.pendingCake(
            pId,
            address(this)
        );

        (uint256 amount, , ) = _pancakeMasterChefV2.userInfo(
            pId,
            address(this)
        );

        require(amount > 0, "oe17");
        _rewards += (_rewardsInPancake * _lpBalance) / amount;
        return (_lpBalance, _rewards);
    }

    function withdrawRewards(uint256 _rewardAmount)
        external
        nonReentrant
        updateRewards
    {
        require(_rewardAmount > 0, "oe18");
        require(userInfo[msg.sender].exist, "oe16");
        require(
            userInfo[msg.sender].distributedReward >= _rewardAmount,
            "oe19"
        );

        userInfo[msg.sender].distributedReward -= _rewardAmount;

        require(address(rewardToken) != address(0), "rewardToken is not set");
        rewardToken.uniTransfer(payable(msg.sender), _rewardAmount);
    }

    function swap(
        IERC20Upgradeable _fromToken,
        uint256 _amount,
        bytes calldata _data
    ) internal override returns (uint256) {
        address _swapContract = swapContract; // gas savings
        if (!_fromToken.isETH()) {
            _fromToken.uniApprove(_swapContract, _amount);
        }
        bytes memory returnData = AddressUpgradeable.functionCallWithValue(
            _swapContract,
            _data,
            _fromToken.isETH() ? _amount : 0
        );
        return abi.decode(returnData, (uint256));
    }

    function addLiquidity(AddLiqDescriptor memory _addLiqDescriptor)
        internal
        override
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        IUniswapV2Router02 _router = router; // gas savings
        tokenA.uniApprove(address(_router), _addLiqDescriptor.amountADesired);
        tokenB.uniApprove(address(_router), _addLiqDescriptor.amountBDesired);
        return
            _router.addLiquidity(
                address(tokenA),
                address(tokenB),
                _addLiqDescriptor.amountADesired,
                _addLiqDescriptor.amountBDesired,
                _addLiqDescriptor.amountAMin,
                _addLiqDescriptor.amountBMin,
                address(this),
                _addLiqDescriptor.deadline
            );
    }

    function removeLiquidity(RemoveLiqDescriptor memory _removeLiqDescriptor)
        internal
        override
        returns (uint256, uint256)
    {
        IUniswapV2Router02 _router = router; // gas savings
        pair.uniApprove(address(_router), _removeLiqDescriptor.amount);
        return
            _router.removeLiquidity(
                address(tokenA),
                address(tokenB),
                _removeLiqDescriptor.amount,
                _removeLiqDescriptor.amountAMin,
                _removeLiqDescriptor.amountBMin,
                _removeLiqDescriptor.receiverAccount,
                _removeLiqDescriptor.deadline
            );
    }

    function stake(address _userAddress, uint256 _amount)
        internal
        override
        updateRewards
    {
        require(_userAddress != address(0), "oe20");

        if (!userInfo[_userAddress].exist) {
            userAddressList.push(_userAddress);
            userInfo[_userAddress].exist = true;
            userInfo[_userAddress].lpBalance = _amount;
        } else {
            userInfo[_userAddress].lpBalance += _amount;
        }
        IPancakeMasterChefV2 _pancakeMasterChefV2 = pancakeMasterChefV2; // gas savings
        pair.uniApprove(address(_pancakeMasterChefV2), _amount);
        _pancakeMasterChefV2.deposit(pId, _amount);
    }

    function unstake(uint256 _amount)
        internal
        override
        updateRewards
        returns (uint256, uint256)
    {
        require(_amount > 0, "oe18");
        require(userInfo[msg.sender].exist, "oe16");
        require(userInfo[msg.sender].lpBalance >= _amount, "oe21");

        IPancakeMasterChefV2 _pancakeMasterChefV2 = pancakeMasterChefV2; // gas savings
        _pancakeMasterChefV2.withdraw(pId, _amount);

        if (userInfo[msg.sender].lpBalance == _amount) {
            uint256 _currentLPRewards = userInfo[msg.sender].distributedReward;

            delete userInfo[msg.sender];
            uint256 index;
            for (uint256 i = 0; i < userAddressList.length; i++) {
                address userAddress = userAddressList[i];
                if (userAddress == msg.sender) {
                    index = i;
                    break;
                }
            }
            userAddressList[index] = userAddressList[
                userAddressList.length - 1
            ];
            userAddressList.pop();

            require(
                address(rewardToken) != address(0),
                "rewardToken is not set"
            );
            rewardToken.uniTransfer(payable(msg.sender), _currentLPRewards);

            return (_amount, 0);
        } else {
            userInfo[msg.sender].lpBalance -= _amount;
            return (_amount, 0);
        }
    }
}

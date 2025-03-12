// SPDX-License-Identifier: MIT

pragma solidity =0.8.9;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721ReceiverUpgradeable.sol";
import "../interface/IERC721.sol";

interface IUniswapV3PositionUtility {
    function getVEMPAmount(uint256 _tokenID) external view returns (uint256);
}

// MasterChefV3 was the master of VEMP. He now governs over VEMPS. He can make VEMPs and he is a fair guy.
//
// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract once VEMPS is sufficiently
// distributed and the community can show to govern itself.
//
// Have fun reading it. Hopefully it's bug-free. God bless.
contract MasterChefV3 is
    Initializable,
    OwnableUpgradeable,
    IERC721ReceiverUpgradeable,
    UUPSUpgradeable
{
    using SafeMathUpgradeable for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        uint256[] erc721TokenId; // v3 lp token
        //
        // We do some fancy math here. Basically, any point in time, the amount of VEMPs
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accVEMPPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accVEMPPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // Info of each pool.
    struct PoolInfo {
        uint256 allocPoint; // How many allocation points assigned to this pool. VEMPs to distribute per block.
        uint256 lastRewardBlock; // Last block number that VEMPs distribution occurs.
        uint256 accVEMPPerShare; // Accumulated VEMPs per share, times 1e12. See below.
    }

    // The VEMP TOKEN!
    IERC20Upgradeable public VEMP;
    // VEMP tokens created per block.
    uint256 public VEMPPerBlock;
    // Bonus muliplier for early VEMP makers.
    uint256 public constant BONUS_MULTIPLIER = 1;
    // uniswap v3 position address
    IUniswapV3PositionUtility public uniswapUtility;
    // uniswap v3 lp erc721 address
    IERC721 public erc721Token;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint;
    // The block number when VEMP mining starts.
    uint256 public startBlock;
    // uniswap v3 pool supply
    uint256 public uniswapV3LpSupply;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );
    event SetUtilityContractAddress(
        IUniswapV3PositionUtility indexed _uniswapUtility
    );
    event SetERC721ContractAddress(IERC721 indexed _erc721);
    event updateVEMPPerBlock(uint indexed _VEMPPerBlock);
    event updateBonusEndBlock(uint indexed _bonusEndBlock);
    event SafeTransfer(address _to, uint _amount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        IERC20Upgradeable _VEMP,
        uint256 _VEMPPerBlock,
        uint256 _startBlock
    ) public initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
	
	require(address(_VEMP) != address(0), "Invalid Address");
	
        VEMP = _VEMP;
        VEMPPerBlock = _VEMPPerBlock;
        startBlock = _startBlock;

        uint256 lastRewardBlock = block.number > startBlock
            ? block.number
            : startBlock;
        totalAllocPoint = totalAllocPoint.add(100);
        poolInfo.push(
            PoolInfo({
                allocPoint: 100,
                lastRewardBlock: lastRewardBlock,
                accVEMPPerShare: 0
            })
        );
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(
        uint256 _from,
        uint256 _to
    ) public pure returns (uint256 _diff) {
        if (_to >= _from) {
            return _to.sub(_from).mul(BONUS_MULTIPLIER);
        } else {
            return 0;
        }
    }

    // View function to see pending VEMPs on frontend.
    function pendingVEMP(
        uint256 _pid,
        address _user
    ) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accVEMPPerShare = pool.accVEMPPerShare;
        uint256 lpSupply = uniswapV3LpSupply;

        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(
                pool.lastRewardBlock,
                block.number
            );
            uint256 VEMPReward = multiplier
                .mul(VEMPPerBlock)
                .mul(pool.allocPoint)
                .div(totalAllocPoint);
            accVEMPPerShare = accVEMPPerShare.add(
                VEMPReward.mul(1e12).div(lpSupply)
            );
        }
        return user.amount.mul(accVEMPPerShare).div(1e12).sub(user.rewardDebt);
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = uniswapV3LpSupply;

        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 VEMPReward = multiplier
            .mul(VEMPPerBlock)
            .mul(pool.allocPoint)
            .div(totalAllocPoint);
        pool.accVEMPPerShare = pool.accVEMPPerShare.add(
            VEMPReward.mul(1e12).div(lpSupply)
        );
        pool.lastRewardBlock = block.number;
    }

    function transferNFTandGetAmount(
        uint256 _tokenId
    ) internal returns (uint256) {
        uint256 _amount;
        address _token0;
        address _token1;

        (, , _token0, _token1, , , , , , , , ) = erc721Token.positions(
            _tokenId
        );
        _amount = uniswapUtility.getVEMPAmount(_tokenId);
        erc721Token.safeTransferFrom(
            address(msg.sender),
            address(this),
            _tokenId
        );

        return _amount;
    }

    // Deposit LP tokens to MasterChefV3 for VEMP allocation.
    function deposit(uint256 _pid, uint256[] memory _tokenIds) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending = user
                .amount
                .mul(pool.accVEMPPerShare)
                .div(1e12)
                .sub(user.rewardDebt);
            safeVEMPTransfer(msg.sender, pending);
        }

        uint totalDeposit = 0;
        if(_tokenIds.length > 0) {
            for (uint256 i = 0; i < _tokenIds.length; i++) {
                uint _amount = transferNFTandGetAmount(_tokenIds[i]);
                user.erc721TokenId.push(_tokenIds[i]);
                uniswapV3LpSupply = uniswapV3LpSupply.add(_amount);
                user.amount = user.amount.add(_amount);
                totalDeposit = totalDeposit.add(_amount);
            }
        }

        user.rewardDebt = user.amount.mul(pool.accVEMPPerShare).div(1e12);
        emit Deposit(msg.sender, _pid, totalDeposit);
    }

    // Withdraw LP tokens from MasterChefV3.
    function withdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount > 0, "withdraw: not good");
        updatePool(_pid);
        uint256 pending = user.amount.mul(pool.accVEMPPerShare).div(1e12).sub(
            user.rewardDebt
        );
        safeVEMPTransfer(msg.sender, pending);

        uint _amount = user.amount;
        uniswapV3LpSupply = uniswapV3LpSupply.sub(_amount);
        user.amount = 0;
        user.rewardDebt = user.amount.mul(pool.accVEMPPerShare).div(1e12);

        uint tokenIdsLength = user.erc721TokenId.length;
        for (uint256 i = tokenIdsLength; i > 0; i--) {
            erc721Token.safeTransferFrom(
                address(this),
                address(msg.sender),
                user.erc721TokenId[i-1]
            );
            user.erc721TokenId.pop();
        }

        emit Withdraw(msg.sender, _pid, _amount);
    }

    function getUserTokenIds(address _user) public view returns(uint[] memory) {
        require(_user != address(0), "Invalid user");
        UserInfo storage user = userInfo[0][_user];
        return user.erc721TokenId;
    }

    // Safe VEMP transfer function, just in case if rounding error causes pool to not have enough VEMPs.
    function safeVEMPTransfer(address _to, uint256 _amount) internal {
        uint256 VEMPBal = VEMP.balanceOf(address(this));
        if (_amount > VEMPBal) {
            VEMP.transfer(_to, VEMPBal);
        } else {
            VEMP.transfer(_to, _amount);
        }

        emit SafeTransfer(_to, _amount);
    }

    // **** Additional functions separate from the original MasterChefV3 contract ****
    function setVEMPPerBlock(uint256 _VEMPPerBlock) public onlyOwner {
        updatePool(0);
        VEMPPerBlock = _VEMPPerBlock;
        emit updateVEMPPerBlock(_VEMPPerBlock);
    }

    function _authorizeUpgrade(address) internal view override {
        require(owner() == msg.sender, "Only owner can upgrade implementation");
    }

    // method to set utility contract address
    function setUtilityContractAddress(
        IUniswapV3PositionUtility _uniswapUtility
    ) external onlyOwner {
    	require(address(_uniswapUtility) != address(0), "Invalid Address");
    	
        uniswapUtility = _uniswapUtility;
        emit SetUtilityContractAddress(_uniswapUtility);
    }

    // method to set v3 pair erc721 contract address
    function setERC721ContractAddress(IERC721 _erc721) external onlyOwner {
    	require(address(_erc721) != address(0), "Invalid Address");
    	
        erc721Token = _erc721;
        emit SetERC721ContractAddress(_erc721);
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return IERC721ReceiverUpgradeable.onERC721Received.selector;
    }
}
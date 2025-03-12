// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "../libraries/math/SafeMath.sol";
import "../libraries/token/IERC20.sol";
import "../libraries/token/SafeERC20.sol";
import "../libraries/utils/ReentrancyGuard.sol";

import "./interfaces/IRewardDistributor.sol";
import "./interfaces/IRewardTracker.sol";
import "../access/Governable.sol";

contract FeeAvtRewardTracker is IERC20, ReentrancyGuard, IRewardTracker, Governable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    uint256 public constant BASIS_POINTS_DIVISOR = 10000;
    uint256 public constant PRECISION = 1e30;

    uint256 public constant daoFundmaxShare = 4000;

    uint8 public constant decimals = 18;

    bool public isInitialized;

    string public name;
    string public symbol;

    address public distributor;
    mapping(address => bool) public isDepositToken;
    mapping(address => mapping(address => uint256)) public override depositBalances;
    mapping(address => uint256) public totalDepositSupply;

    uint256 public override totalSupply;
    mapping(address => uint256) public balances;
    mapping(address => mapping(address => uint256)) public allowances;

    uint256 public cumulativeRewardPerToken;
    uint256 public daoFundCumulativeRewardPerToken;
    mapping(address => uint256) public override stakedAmounts;
    mapping(address => uint256) public claimableReward;
    mapping(address => uint256) public previousCumulatedRewardPerToken;
    uint256 public previousDaoFundCumulatedRewardPerToken;
    mapping(address => uint256) public override cumulativeRewards;
    mapping(address => uint256) public override averageStakedAmounts;

    address public daoFund;
    bool public inPrivateTransferMode;
    bool public inPrivateStakingMode;
    bool public inPrivateClaimingMode;
    mapping(address => bool) public isHandler;

    event Claim(address receiver, uint256 amount);

    constructor(string memory _name, string memory _symbol) public {
        name = _name;
        symbol = _symbol;
    }

    function initialize(
        address[] memory _depositTokens,
        address _distributor,
        address _daoFund
    ) external onlyGov {
        require(!isInitialized, "RewardTracker: already initialized");
        isInitialized = true;

        for (uint256 i = 0; i < _depositTokens.length; i++) {
            address depositToken = _depositTokens[i];
            isDepositToken[depositToken] = true;
        }

        distributor = _distributor;
        daoFund = _daoFund;
    }

    function setDepositToken(address _depositToken, bool _isDepositToken) external onlyGov {
        isDepositToken[_depositToken] = _isDepositToken;
    }

    function setInPrivateTransferMode(bool _inPrivateTransferMode) external onlyGov {
        inPrivateTransferMode = _inPrivateTransferMode;
    }

    function setInPrivateStakingMode(bool _inPrivateStakingMode) external onlyGov {
        inPrivateStakingMode = _inPrivateStakingMode;
    }

    function setInPrivateClaimingMode(bool _inPrivateClaimingMode) external onlyGov {
        inPrivateClaimingMode = _inPrivateClaimingMode;
    }

    function setHandler(address _handler, bool _isActive) external onlyGov {
        isHandler[_handler] = _isActive;
    }

    // to help users who accidentally send their tokens to this contract
    function withdrawToken(address _token, address _account, uint256 _amount) external onlyGov {
        IERC20(_token).safeTransfer(_account, _amount);
    }

    function balanceOf(address _account) external view override returns (uint256) {
        return balances[_account];
    }

    function stake(address _depositToken, uint256 _amount) external override nonReentrant {
        if (inPrivateStakingMode) {
            revert("RewardTracker: action not enabled");
        }
        _stake(msg.sender, msg.sender, _depositToken, _amount);
    }

    function stakeForAccount(
        address _fundingAccount,
        address _account,
        address _depositToken,
        uint256 _amount
    ) external override nonReentrant {
        _validateHandler();
        _stake(_fundingAccount, _account, _depositToken, _amount);
    }

    function unstake(address _depositToken, uint256 _amount) external override nonReentrant {
        if (inPrivateStakingMode) {
            revert("RewardTracker: action not enabled");
        }
        _unstake(msg.sender, _depositToken, _amount, msg.sender);
    }

    function unstakeForAccount(
        address _account,
        address _depositToken,
        uint256 _amount,
        address _receiver
    ) external override nonReentrant {
        _validateHandler();
        _unstake(_account, _depositToken, _amount, _receiver);
    }

    function transfer(address _recipient, uint256 _amount) external override returns (bool) {
        _transfer(msg.sender, _recipient, _amount);
        return true;
    }

    function allowance(address _owner, address _spender) external view override returns (uint256) {
        return allowances[_owner][_spender];
    }

    function approve(address _spender, uint256 _amount) external override returns (bool) {
        _approve(msg.sender, _spender, _amount);
        return true;
    }

    function transferFrom(
        address _sender,
        address _recipient,
        uint256 _amount
    ) external override returns (bool) {
        if (isHandler[msg.sender]) {
            _transfer(_sender, _recipient, _amount);
            return true;
        }

        uint256 nextAllowance = allowances[_sender][msg.sender].sub(
            _amount,
            "RewardTracker: transfer amount exceeds allowance"
        );
        _approve(_sender, msg.sender, nextAllowance);
        _transfer(_sender, _recipient, _amount);
        return true;
    }

    function tokensPerInterval() external view override returns (uint256) {
        return IRewardDistributor(distributor).tokensPerInterval();
    }

    function updateRewards() external override nonReentrant {
        _updateRewards(address(0));
    }

    function claim(address _receiver) external override nonReentrant returns (uint256) {
        if (inPrivateClaimingMode) {
            revert("RewardTracker: action not enabled");
        }
        return _claim(msg.sender, _receiver);
    }

    function claimForAccount(
        address _account,
        address _receiver
    ) external override nonReentrant returns (uint256) {
        _validateHandler();
        return _claim(_account, _receiver);
    }

    function claimable(address _account) public view override returns (uint256) {
        uint256 stakedAmount = stakedAmounts[_account];
        if (stakedAmount == 0) {
            return claimableReward[_account];
        }

        uint256 nextDaoFundCumulativeRewardPerToken = daoFundCumulativeRewardPerToken;
        uint256 nextCumulativeRewardPerToken = cumulativeRewardPerToken;

        {
            uint256 supply = totalSupply;
            uint256 pendingRewards = IRewardDistributor(distributor).pendingRewards().mul(
                PRECISION
            );

            uint256 daoFundStakedAmounts = stakedAmounts[daoFund];
            uint256 usersStakedAmounts = supply.sub(daoFundStakedAmounts);

            uint256 daoFundPendingRewards = pendingRewards.mul(daoFundStakedAmounts).div(supply);
            if (
                daoFundStakedAmounts < supply &&
                daoFundStakedAmounts > supply.mul(daoFundmaxShare).div(BASIS_POINTS_DIVISOR)
            ) {
                daoFundPendingRewards = pendingRewards.mul(daoFundmaxShare).div(
                    BASIS_POINTS_DIVISOR
                );
            }
            uint256 usersPendingRewards = pendingRewards.sub(daoFundPendingRewards);

            if (daoFundStakedAmounts > 0) {
                nextDaoFundCumulativeRewardPerToken = nextDaoFundCumulativeRewardPerToken.add(
                    daoFundPendingRewards.div(daoFundStakedAmounts)
                );
            }
            if (usersStakedAmounts > 0) {
                nextCumulativeRewardPerToken = nextCumulativeRewardPerToken.add(
                    usersPendingRewards.div(usersStakedAmounts)
                );
            }
        }
        if (_account == daoFund) {
            return
                claimableReward[_account].add(
                    stakedAmount
                        .mul(
                            nextDaoFundCumulativeRewardPerToken.sub(
                                previousDaoFundCumulatedRewardPerToken
                            )
                        )
                        .div(PRECISION)
                );
        }
        return
            claimableReward[_account].add(
                stakedAmount
                    .mul(
                        nextCumulativeRewardPerToken.sub(previousCumulatedRewardPerToken[_account])
                    )
                    .div(PRECISION)
            );
    }

    function rewardToken() public view returns (address) {
        return IRewardDistributor(distributor).rewardToken();
    }

    function _claim(address _account, address _receiver) private returns (uint256) {
        _updateRewards(_account);

        uint256 tokenAmount = claimableReward[_account];
        claimableReward[_account] = 0;

        if (tokenAmount > 0) {
            IERC20(rewardToken()).safeTransfer(_receiver, tokenAmount);
            emit Claim(_account, tokenAmount);
        }

        return tokenAmount;
    }

    function _mint(address _account, uint256 _amount) internal {
        require(_account != address(0), "RewardTracker: mint to the zero address");

        totalSupply = totalSupply.add(_amount);
        balances[_account] = balances[_account].add(_amount);

        emit Transfer(address(0), _account, _amount);
    }

    function _burn(address _account, uint256 _amount) internal {
        require(_account != address(0), "RewardTracker: burn from the zero address");

        balances[_account] = balances[_account].sub(
            _amount,
            "RewardTracker: burn amount exceeds balance"
        );
        totalSupply = totalSupply.sub(_amount);

        emit Transfer(_account, address(0), _amount);
    }

    function _transfer(address _sender, address _recipient, uint256 _amount) private {
        require(_sender != address(0), "RewardTracker: transfer from the zero address");
        require(_recipient != address(0), "RewardTracker: transfer to the zero address");

        if (inPrivateTransferMode) {
            _validateHandler();
        }

        balances[_sender] = balances[_sender].sub(
            _amount,
            "RewardTracker: transfer amount exceeds balance"
        );
        balances[_recipient] = balances[_recipient].add(_amount);

        emit Transfer(_sender, _recipient, _amount);
    }

    function _approve(address _owner, address _spender, uint256 _amount) private {
        require(_owner != address(0), "RewardTracker: approve from the zero address");
        require(_spender != address(0), "RewardTracker: approve to the zero address");

        allowances[_owner][_spender] = _amount;

        emit Approval(_owner, _spender, _amount);
    }

    function _validateHandler() private view {
        require(isHandler[msg.sender], "RewardTracker: forbidden");
    }

    function _stake(
        address _fundingAccount,
        address _account,
        address _depositToken,
        uint256 _amount
    ) private {
        require(_amount > 0, "RewardTracker: invalid _amount");
        require(isDepositToken[_depositToken], "RewardTracker: invalid _depositToken");

        IERC20(_depositToken).safeTransferFrom(_fundingAccount, address(this), _amount);

        _updateRewards(_account);

        stakedAmounts[_account] = stakedAmounts[_account].add(_amount);
        depositBalances[_account][_depositToken] = depositBalances[_account][_depositToken].add(
            _amount
        );
        totalDepositSupply[_depositToken] = totalDepositSupply[_depositToken].add(_amount);

        _mint(_account, _amount);
    }

    function _unstake(
        address _account,
        address _depositToken,
        uint256 _amount,
        address _receiver
    ) private {
        require(_amount > 0, "RewardTracker: invalid _amount");
        require(isDepositToken[_depositToken], "RewardTracker: invalid _depositToken");

        _updateRewards(_account);

        uint256 stakedAmount = stakedAmounts[_account];
        require(stakedAmounts[_account] >= _amount, "RewardTracker: _amount exceeds stakedAmount");

        stakedAmounts[_account] = stakedAmount.sub(_amount);

        uint256 depositBalance = depositBalances[_account][_depositToken];
        require(depositBalance >= _amount, "RewardTracker: _amount exceeds depositBalance");
        depositBalances[_account][_depositToken] = depositBalance.sub(_amount);
        totalDepositSupply[_depositToken] = totalDepositSupply[_depositToken].sub(_amount);

        _burn(_account, _amount);
        IERC20(_depositToken).safeTransfer(_receiver, _amount);
    }

    function _updateRewards(address _account) private {
        uint256 blockReward = IRewardDistributor(distributor).distribute();

        uint256 supply = totalSupply;
        uint256 _cumulativeRewardPerToken = cumulativeRewardPerToken;
        uint256 _daoFundCumulativeRewardPerToken = daoFundCumulativeRewardPerToken;

        {
            uint256 daoFundStakedAmounts;
            uint256 daoFundBlockReward;
            if (supply > 0 && blockReward > 0) {
                daoFundStakedAmounts = stakedAmounts[daoFund];
                daoFundBlockReward = blockReward.mul(daoFundStakedAmounts).div(supply);
                if (
                    daoFundStakedAmounts < supply &&
                    daoFundStakedAmounts > supply.mul(daoFundmaxShare).div(BASIS_POINTS_DIVISOR)
                ) {
                    daoFundBlockReward = blockReward.mul(daoFundmaxShare).div(BASIS_POINTS_DIVISOR);
                }
                if (daoFundStakedAmounts > 0 && daoFundBlockReward > 0) {
                    _daoFundCumulativeRewardPerToken = _daoFundCumulativeRewardPerToken.add(
                        daoFundBlockReward.mul(PRECISION).div(daoFundStakedAmounts)
                    );
                    daoFundCumulativeRewardPerToken = _daoFundCumulativeRewardPerToken;
                }
            }
            uint256 _usersBlockReward = blockReward.sub(daoFundBlockReward);
            uint256 _usersStakedAmounts = supply.sub(daoFundStakedAmounts);
            if (_usersStakedAmounts > 0 && _usersBlockReward > 0) {
                _cumulativeRewardPerToken = _cumulativeRewardPerToken.add(
                    _usersBlockReward.mul(PRECISION).div(_usersStakedAmounts)
                );
                cumulativeRewardPerToken = _cumulativeRewardPerToken;
            }
        }

        // cumulativeRewardPerToken can only increase
        // so if cumulativeRewardPerToken is zero, it means there are no rewards yet
        if (_cumulativeRewardPerToken == 0 && _daoFundCumulativeRewardPerToken == 0) {
            return;
        }

        if (_account != address(0)) {
            uint256 stakedAmount = stakedAmounts[_account];
            uint256 accountReward;
            if (_account == daoFund) {
                accountReward = stakedAmount
                    .mul(
                        _daoFundCumulativeRewardPerToken.sub(previousDaoFundCumulatedRewardPerToken)
                    )
                    .div(PRECISION);
                previousDaoFundCumulatedRewardPerToken = _daoFundCumulativeRewardPerToken;
            } else {
                accountReward = stakedAmount
                    .mul(_cumulativeRewardPerToken.sub(previousCumulatedRewardPerToken[_account]))
                    .div(PRECISION);
                previousCumulatedRewardPerToken[_account] = _cumulativeRewardPerToken;
            }
            uint256 _claimableReward = claimableReward[_account].add(accountReward);

            claimableReward[_account] = _claimableReward;

            if (_claimableReward > 0 && stakedAmounts[_account] > 0) {
                uint256 nextCumulativeReward = cumulativeRewards[_account].add(accountReward);

                uint256 _cumulativeRewards = cumulativeRewards[_account];
                uint256 _averageStakedAmounts = averageStakedAmounts[_account];
                _averageStakedAmounts = _averageStakedAmounts
                    .mul(_cumulativeRewards)
                    .div(nextCumulativeReward)
                    .add(stakedAmount.mul(accountReward).div(nextCumulativeReward));
                averageStakedAmounts[_account] = _averageStakedAmounts;
                cumulativeRewards[_account] = nextCumulativeReward;
            }
        }
    }
}

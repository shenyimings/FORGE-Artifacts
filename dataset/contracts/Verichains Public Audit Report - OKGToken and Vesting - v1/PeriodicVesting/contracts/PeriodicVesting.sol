// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./IVesting.sol";

contract PeriodicVesting is Ownable, ReentrancyGuard, IVesting {
    using SafeERC20 for IERC20;

    struct PoolPolicy {
        uint256 TGEratio;
        uint256 TGEdenom;
        uint256 TGEtime;
        uint256 vestingStart;
        uint256 vestingEnd;
        uint256 period;
        uint256 totalPeriodNum;
    }

    struct Beneficiary {
        uint256 allocated;
        uint256 claimed;
        uint256 policy;
    }

    IERC20 public token;

    bool public locked;
    PoolPolicy[] public policies;

    address[] public beneficiariesList;
    mapping(address => Beneficiary) public beneficiaries;

    event Released(
        address indexed beneficiary,
        uint256 currentTime,
        uint256 amount
    );

    modifier isNotLocked() {
        require(!locked, "Locked already");
        _;
    }

    modifier zeroAddr(address _addr) {
        require(_addr != address(0), "Address must not be zero");
        _;
    }

    constructor(address _token) Ownable() {
        require(_token != address(0), "Address must not be zero");
        token = IERC20(_token);
    }

    /**
        @notice Set policy and vesting timeline
        @param _TGEratio amount to release on TGE in `_TGEdenom` of total allocated
        @param _TGEdenom denominator of `_TGEratio`
        @param _TGEtime moment of TGE
        @param _vestingStart moment of vesting duration start
        @param _vestingEnd last of vesting time, return last vesting on this timestamp
        @param _period duration of an vesting period
     */
    function setPolicy(
        uint256 _TGEratio,
        uint256 _TGEdenom,
        uint256 _TGEtime,
        uint256 _vestingStart,
        uint256 _vestingEnd,
        uint256 _period
    ) external onlyOwner isNotLocked {
        require(
            (_vestingEnd - _vestingStart) % _period == 0,
            "Vesting timeline invalid"
        );

        require(_vestingStart > _TGEtime, "Vesting must start after TGE");
        uint256 _totalPeriodNum = (_vestingEnd - _vestingStart) / _period + 1;
        policies.push(
            PoolPolicy(
                _TGEratio,
                _TGEdenom,
                _TGEtime,
                _vestingStart,
                _vestingEnd,
                _period,
                _totalPeriodNum
            )
        );
    }

    function getTotalAllocated(address _beneficiary)
        external
        view
        returns (uint256)
    {
        return beneficiaries[_beneficiary].allocated;
    }

    /**
        @notice Enable the lock state of setting
        @dev Caller must be Owner
        Note:
        - Set value of `locked` to `true`
        - When `locked = true`, setVesting() will be locked
        and additional vesting policies can't be added
        - No method to unlock this state
    */
    function lock() external onlyOwner isNotLocked {
        locked = true;
    }

    /**
        @notice add beneficiary
        @dev Caller must be Owner
        Not allow Owner to alter the vesting policy
        @param _beneficiary `_beneficiary` address
        @param _totalAmt Amount that `_beneficiary` can claim in total
        @param _policy index of the correspond policy for beneficiary
    */
    function addBeneficiary(
        address _beneficiary,
        uint256 _totalAmt,
        uint256 _policy
    ) public onlyOwner isNotLocked zeroAddr(_beneficiary) {
        require(_policy < policies.length, "Policy not existed");
        require(beneficiaries[_beneficiary].allocated == 0, "Already added");
        beneficiaries[_beneficiary] = Beneficiary(_totalAmt, 0, _policy);

        beneficiariesList.push(_beneficiary);
    }

    /**
        @notice add multiple beneficiaries
        @dev Caller must be Owner
        Not allow Owner to alter the vesting policy
        @param _beneficiaries all `_beneficiaries` address
        @param _totalAmt Amount that corresponding `_beneficiary` can claim in total 
    */
    function addBeneficiaries(
        address[] calldata _beneficiaries,
        uint256[] calldata _totalAmt,
        uint256[] calldata _policies
    ) external onlyOwner isNotLocked {
        require(
            _beneficiaries.length == _totalAmt.length,
            "Invalid array length"
        );
        for (uint256 i = 0; i < _beneficiaries.length; i++) {
            addBeneficiary(_beneficiaries[i], _totalAmt[i], _policies[i]);
        }
    }

    /**
        @notice Query available amount that `_beneficiary` is able to claim at the moment
        @dev Caller can be ANY
    */
    function getAvailAmt(address _beneficiary)
        public
        view
        override
        returns (uint256 _amount)
    {
        Beneficiary memory _bene = beneficiaries[_beneficiary];
        PoolPolicy memory _policy = policies[_bene.policy];
        uint256 tgeAmnt = (_bene.allocated * _policy.TGEratio) /
            _policy.TGEdenom;
        if (block.timestamp > _policy.TGEtime) {
            _amount += tgeAmnt;
        }

        if (
            block.timestamp < _policy.vestingEnd &&
            block.timestamp > _policy.vestingStart
        ) {
            uint256 numberPeriod = (block.timestamp - _policy.vestingStart) /
                _policy.period +
                1;
            _amount +=
                (numberPeriod * (_bene.allocated - tgeAmnt)) /
                _policy.totalPeriodNum;
        } else if (block.timestamp >= _policy.vestingEnd) {
            _amount = _bene.allocated;
        }

        _amount -= _bene.claimed;
    }

    function claimed(address _beneficiary)
        external
        view
        override
        returns (uint256)
    {
        return beneficiaries[_beneficiary].claimed;
    }

    /**
        @notice Beneficiaries use this method to claim vesting tokens
        @dev Caller can be any
        Note: 
        - Only Beneficiaries, who were added into the list, are able to claim tokens
        - If `_policy`, that binds to msg.sender, is not found -> revert
        - Previously unclaimed amounts will be accumulated
    */
    function claim() external override nonReentrant {
        claim(_msgSender());
    }

    function claim(address _beneficiary) internal {
        require(
            beneficiaries[_beneficiary].allocated != 0,
            "Beneficiary not existed"
        );

        uint256 _amount = getAvailAmt(_beneficiary);
        if (_amount == 0) {
            return;
        }

        beneficiaries[_beneficiary].claimed += _amount;
        _releaseTokenTo(_beneficiary, block.timestamp, _amount);
    }

    /**
        @notice Owner call this to realease token to all beneficiaries
        @dev Caller can be owner only
    */
    function release() external override nonReentrant onlyOwner {
        for (uint256 i = 0; i < beneficiariesList.length; i++) {
            claim(beneficiariesList[i]);
        }
    }

    /**
        @notice Owner call this to withdraw all vesting token
        @dev Caller can be owner only
    */
    function withdraw() external onlyOwner {
        uint256 bal = token.balanceOf(address(this));
        token.safeTransfer(_msgSender(), bal);
    }

    function _releaseTokenTo(
        address _beneficiary,
        uint256 _now,
        uint256 _amount
    ) private {
        token.safeTransfer(_beneficiary, _amount);

        emit Released(_beneficiary, _now, _amount);
    }
}

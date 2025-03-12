pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./Interfaces/IVestingFlex.sol";

/// @notice DO NOT SEND TOKENS TO THIS CONTRACT
/// @title different schedules, different beneficiaries, one token
contract VestingFlex is OwnableUpgradeable, IVestingFlex {
    using SafeERC20 for IERC20;

    string constant private ZERO_VALUE_ERROR = "param is zero";
    uint256 constant private PRECISISION = 1_000_000_000;
    address internal token_;

    bool public adminCanRevokeGlobal;

    mapping(address => Vesting[]) private _vestingsByUser;

    constructor() {
        _disableInitializers();
    }

    function initialize(address _token, address _owner) external initializer {
        __Ownable_init();
        token_ = _token;
        adminCanRevokeGlobal = true;
        _transferOwnership(_owner);
    }


    //// USER ////

    /// @notice sends all vested tokens to the vesting who
    /// @notice call `getClaimableNow()` to see the amount of available tokens
    /// @param which index of the vesting that should be claimed. 0 in most cases
    function retrieve(uint256 which) external override returns(uint256) {
        return _retrieve(msg.sender, which);
    }


    //// OWNER ////

    /// @notice create multiple vestings at once for different beneficiaries
    /// @param patron the one paying for the Vestings 
    /// @param beneficiaries the recipients of `vestings` in the same order
    /// @param vestings the vesting schedules in order for recipients
    function createVestings(
        address patron, 
        address[] calldata beneficiaries, 
        Vesting[] calldata vestings
    ) external override onlyOwner {
        require(beneficiaries.length == vestings.length, "length mismatch");

        uint256 totalAmount;
        for(uint256 i = 0; i < vestings.length; i++) {
            address who = beneficiaries[i];
            Vesting calldata vesting = vestings[i];

            totalAmount += vesting.vestedTotal;
            _pushVesting(who, vesting);
        }
        _processPayment(patron, address(this), totalAmount);
    }

    /// @notice reduces the vested amount and sends the difference in tokens to `tokenReceiver`
    /// @param who address that the tokens are vested for
    /// @param which index of the vesting for `who`
    /// @param amountToReduceTo new total amount for the vesting
    /// @param tokenReceiver address receiving the tokens that are not needed for vesting anymore
    function reduceVesting(
        address who, 
        uint256 which, 
        uint128 amountToReduceTo,
        bool revokeComplete,
        address tokenReceiver
    ) external override onlyOwner {
        require(adminCanRevokeGlobal, "admin not allowed to revoke anymore");

        Vesting storage vesting = _vestingsByUser[who][which];
        uint128 amountBefore = vesting.vestedTotal;

        // we give what was already released to `who`
        _retrieve(who, which);

        require(vesting.revokable, "vesting non-revokable");

        if(revokeComplete) {
            amountToReduceTo = vesting.claimedTotal;
        } else {
            require(amountToReduceTo >= vesting.claimedTotal, "cannot reduce, already claimed");
        }

        require(amountBefore > amountToReduceTo, "must reduce");
        vesting.vestedTotal = amountToReduceTo;

        _processPayment(address(this), tokenReceiver, amountBefore - amountToReduceTo);

        emit VestingReduced(who, which, amountBefore, amountToReduceTo);
    }

    function ownerRetrieveFor(address who, uint256 which) external onlyOwner {
        require(_retrieve(who, which) != 0, "nothing to retrieve");
    }

    /// @notice when this function is called once, the owner of this
    ///         contract cannot revoke vestings, once they are created
    function disableOwnerRevokeGlobally() external override onlyOwner {
        require(adminCanRevokeGlobal);
        adminCanRevokeGlobal = false;
        emit OwnerRevokeDisabledGlobally(block.timestamp);
    }

    /// @notice same as `disableOwnerRevokeGlobally`, but for a specific vesting
    function disableOwnerRevoke(address who, uint256 which) external override onlyOwner {
        _enforceVestingExists(who, which);

        Vesting storage vesting = _vestingsByUser[who][which];
        require(vesting.revokable, "not revokable");
        vesting.revokable = false;
        emit OwnerRevokeDisabled(who, which);
    }

    function recoverWrongToken(address _token) external onlyOwner {
        require(_token != token_, "cannot retrieve vested token");
        if(_token == address(0)) {
            msg.sender.call{ value: address(this).balance }("");
        } else {
            IERC20(_token).safeTransfer(msg.sender, IERC20(_token).balanceOf(address(this)));
        }
    }


    //// INTERNAL ////

    /// @dev sends all claimable token in the vesting to `who` and updates vesting
    function _retrieve(address who, uint256 which) internal returns(uint256) {
        _enforceVestingExists(who, which);

        Vesting storage vesting = _vestingsByUser[who][which];
        uint256 totalReleased = _releasedAt(vesting, block.timestamp);
        uint256 claimedTotalBefore = vesting.claimedTotal;


        // check this to not block `reduceVesting()`
        if(totalReleased < claimedTotalBefore) {
            if(msg.sender == owner()) return 0;
            revert("already claimed");
        }

        vesting.claimedTotal = uint128(totalReleased);
        
        uint256 claimable = totalReleased - claimedTotalBefore;
        _processPayment(address(this), who, claimable);
        /* IERC20(token).transfer(who, claimable); */

        emit Retrieved(who, claimable);

        return claimable;
    }

    /// @dev pushes a new vesting in the Vestings array of recipient
    function _pushVesting(address recipient, Vesting calldata vesting) internal {
        _enforceVestingParams(recipient, vesting);
        _vestingsByUser[recipient].push(vesting);
        emit VestingCreated(recipient, _vestingsByUser[recipient].length - 1, vesting);
    }

    function _processPayment(address from, address to, uint256 amount) internal {
        if(amount == 0) return;
        if(from == address(this)) {
            IERC20(token_).safeTransfer(to, amount);
        } else {
            IERC20(token_).safeTransferFrom(from, to, amount);
        }
    }

    /// @dev throws if vesting parameters are 'nonsensical'
    function _enforceVestingParams(address recipient, Vesting calldata vesting) internal view {
        require(recipient != address(0), ZERO_VALUE_ERROR);

        require(vesting.vestedTotal != 0, ZERO_VALUE_ERROR);
        require(vesting.claimedTotal == 0, "claimed == 0");
        require(vesting.cliff <= PRECISISION, "cliff <= MAX_CLIFF");
        require(vesting.start > vesting.cliffDelay);
        require(vesting.start + vesting.duration > block.timestamp, "end must be in future");
        if(vesting.cliff == 0) require(vesting.cliffDelay == 0);
    }

    /// @dev throws if the vesting does not exist
    function _enforceVestingExists(address who, uint256 which) internal view {
        require(_vestingsByUser[who].length > which, "vesting doesnt exist");
    }

    /// @dev calculates the fraction of the total amount that can be retrieved at a given timestamp. 
    ///      Based on `PRECISION`
    function _releasedFractionAt(Vesting storage vesting, uint256 timestamp) internal view returns(uint256) {
        uint256 start = vesting.start;

        if(timestamp + vesting.cliffDelay < start) {
            return 0;
        }
        if(timestamp < start) {
            return vesting.cliff;
        }
        uint256 exp      = vesting.exp;
        uint256 fraction = (PRECISISION * (timestamp - start) ** exp) / (uint256(vesting.duration) ** exp)  + vesting.cliff;
        if (fraction < PRECISISION) {
            return fraction;
        }
        return PRECISISION;
    }

    ///@dev calculates the amount of tokens that can be retrieved at a given timestamp. 
    function _releasedAt(Vesting storage vesting, uint256 timestamp) internal view returns(uint256) {
        return _releasedFractionAt(vesting, timestamp) * uint256(vesting.vestedTotal) / PRECISISION;
    }


    //// EXTERNAL VIEW ////

    /// @return amount number of tokens that are released in the vesting at a given timestamp

    function getReleasedAt(address who, uint256 which, uint256 timestamp) external view override returns(uint256) {
        _enforceVestingExists(who, which);
        return _releasedAt(_vestingsByUser[who][which], timestamp);
    }

    /// @return amount number of tokens that are released in the vesting at the moment
    function getReleased(address who, uint256 which) external view override returns(uint256) {
        _enforceVestingExists(who, which);
        return _releasedAt(_vestingsByUser[who][which], block.timestamp);
    }

    /// @return amount number of tokens that were already retrieved in the vesting
    function getClaimed(address who, uint256 which) external view override returns(uint256) {
        _enforceVestingExists(who, which);
        return _vestingsByUser[who][which].claimedTotal;
    }

    function getClaimableAtTimestamp(address who, uint256 which, uint256 when) public view override returns(uint256) {
        _enforceVestingExists(who, which);

        uint256 released =  _releasedAt(_vestingsByUser[who][which], when);
        uint256 claimed  = _vestingsByUser[who][which].claimedTotal;
        return claimed >= released ? 0 : released - claimed;
    }

    /// @return amount number of tokens that can be retrieved in the vesting at the moment
    function getClaimableNow(address who, uint256 which) external view override returns(uint256) {
        return getClaimableAtTimestamp(who, which, block.timestamp);
    }

    /// @return numberOfVestings the amount of vestings `who` has
    /// @notice call `getVesting(who, x (x < numberOfVestings))` to see the details for each vesting
    function getNumberOfVestings(address who) external view override returns(uint256) {
        return _vestingsByUser[who].length;
    }

    /// @param who beneficiary of the vesting
    /// @param which index of the vesting in the list of vestings for `who`
    /// @notice check `getNumberOfVestings(who)` for the smallest out-of-bound `which`
    function getVesting(address who, uint256 which) external view override returns(Vesting memory) {
        _enforceVestingExists(who, which);
        return _vestingsByUser[who][which];
    }

    /// @return canRevoke false, when the admin cannot revoke the vesting, true otherwise
    function canAdminRevoke(address who, uint256 which) external view override returns(bool) {
        _enforceVestingExists(who, which);
        return adminCanRevokeGlobal && _vestingsByUser[who][which].revokable;
    }

    function balanceOf(address who) external view returns(uint256 sum) {
        Vesting[] storage vestings = _vestingsByUser[who];
        uint256 len = vestings.length;
        for(uint256 i = 0; i < len; i++) {
            sum = sum + vestings[i].vestedTotal - vestings[i].claimedTotal;
        }
    }

    function token() external view override returns(address) {
        return token_;
    }
}
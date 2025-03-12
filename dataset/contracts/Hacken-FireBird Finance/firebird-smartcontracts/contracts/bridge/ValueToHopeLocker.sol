// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import "@openzeppelin/contracts-ethereum-package/contracts/access/Ownable.sol";

import "../interfaces/ITokenLocker.sol";
import "../interfaces/ICappedMintableBurnableERC20.sol";

contract ValueToHopeLocker is OwnableUpgradeSafe, ITokenLocker {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public hope = address(0xd78C475133731CD54daDCb430F7aAE4F03C1E660);

    mapping(address => bool) public authorities;

    uint256 private _startReleaseTime;
    uint256 private _endReleaseTime;

    uint256 private _totalLock;
    uint256 private _totalReleased;
    mapping(address => uint256) private _locks;
    mapping(address => uint256) private _released;

    mapping(bytes32 => bool) public lockedReceipt; // tx_hash => claimed?

    event Lock(address indexed to, uint256 value);
    event UnLock(address indexed account, uint256 value);
    event EditLocker(uint256 indexed _startReleaseTime, uint256 _endReleaseTime);

    modifier isAuthorised() {
        require(authorities[msg.sender], "!authorised");
        _;
    }

    function initialize(address _hope, uint256 startReleaseTime_, uint256 endReleaseTime_) public initializer {
        OwnableUpgradeSafe.__Ownable_init();
        require(endReleaseTime_ > startReleaseTime_, "ValueToHopeLocker: endReleaseTime_ is before startReleaseTime_");
        hope = _hope;
        _startReleaseTime = startReleaseTime_;
        _endReleaseTime = endReleaseTime_;
        emit EditLocker(startReleaseTime_, endReleaseTime_);
    }

    function editLocker(uint256 startReleaseTime_, uint256 endReleaseTime_) external onlyOwner {
        require(_totalLock == 0 || (_startReleaseTime > block.number && startReleaseTime_ > block.number), "ValueToHopeLocker: late");
        require(endReleaseTime_ > startReleaseTime_ && endReleaseTime_ <= startReleaseTime_.add(20 weeks), "ValueToHopeLocker: invalid _endReleaseTime");
        _startReleaseTime = startReleaseTime_;
        _endReleaseTime = endReleaseTime_;
        emit EditLocker(startReleaseTime_, endReleaseTime_);
    }

    function addAuthority(address authority) external onlyOwner {
        authorities[authority] = true;
    }

    function removeAuthority(address authority) external onlyOwner {
        authorities[authority] = false;
    }

    function startReleaseTime() external override view returns (uint256) {
        return _startReleaseTime;
    }

    function endReleaseTime() external override view returns (uint256) {
        return _endReleaseTime;
    }

    function totalLock() external override view returns (uint256) {
        return _totalLock;
    }

    function totalReleased() external override view returns (uint256) {
        return _totalReleased;
    }

    function lockOf(address _account) external override view returns (uint256) {
        return _locks[_account];
    }

    function released(address _account) external override view returns (uint256) {
        return _released[_account];
    }

    function lock(address _account, uint256 _amount, bytes32 _tx) external override isAuthorised {
        require(_account != address(0), "ValueToHopeLocker: no lock to address(0)");
        require(_amount > 0, "ValueToHopeLocker: zero lock");
        require(!lockedReceipt[_tx], "ValueToHopeLocker: already locked");

        lockedReceipt[_tx] = true;
        _locks[_account] = _locks[_account].add(_amount);
        _totalLock = _totalLock.add(_amount);
        emit Lock(_account, _amount);
    }

    function canUnlockAmount(address _account) public override view returns (uint256) {
        if (now < _startReleaseTime) {
            return 0;
        } else if (now >= _endReleaseTime) {
            return _locks[_account].sub(_released[_account]);
        } else {
            uint256 _releasedBlock = now.sub(_startReleaseTime);
            uint256 _totalVestingBlock = _endReleaseTime.sub(_startReleaseTime);
            return _locks[_account].mul(_releasedBlock).div(_totalVestingBlock).sub(_released[_account]);
        }
    }

    function unlock() external {
        claimUnlocked();
    }

    function claimUnlocked() public override {
        claimUnlockedFor(msg.sender);
    }

    function claimUnlockedFor(address _account) public override {
        require(now > _startReleaseTime, "ValueToHopeLocker: still locked");
        require(_locks[_account] > _released[_account], "ValueToHopeLocker: no locked");

        uint256 _amount = canUnlockAmount(_account);
        ICappedMintableBurnableERC20(hope).mint(_account, _amount);

        _released[_account] = _released[_account].add(_amount);
        _totalReleased = _totalReleased.add(_amount);
        _totalLock = _totalLock.sub(_amount);

        emit UnLock(_account, _amount);
    }

    // This function allows governance to take unsupported tokens out of the contract. This is in an effort to make someone whole, should they seriously mess up.
    // There is no guarantee governance will vote to return these. It also allows for removal of airdropped tokens.
    function governanceRecoverUnsupported(address _token, address _to, uint256 _amount) external onlyOwner {
        require(_token != hope || IERC20(hope).balanceOf(address(this)).sub(_amount) >= _totalLock, "ValueToHopeLocker: Not enough locked amount left");
        IERC20(_token).safeTransfer(_to, _amount);
    }
}

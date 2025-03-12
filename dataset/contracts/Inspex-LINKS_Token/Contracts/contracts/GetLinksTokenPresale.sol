// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract GetLinksTokenPresale is Ownable {
    using SafeERC20 for IERC20;

    event TotalSupplyIncreased(address indexed sender, uint256 amount, uint256 totalSupply);
    event Fund(address indexed sender, uint256 amount);
    event Claim(address indexed sender, uint256 amount, uint256 refund);
    event TransferredToTreasury(
        address indexed sender,
        address indexed treasuryAddress,
        uint256 getlinks,
        uint256 usd
    );

    IERC20 public getlinksToken;
    IERC20 public busdToken;
    address public treasuryAddress;

    uint256 public totalSupply;
    uint256 public totalFundInUsd;
    uint256 public presaleRate = 100;

    uint256 public startTime;
    uint256 public endTime;
    bool public isTransferredToTreasury;

    struct UserInfo {
        uint256 fundInUsd;
        bool isClaimed;
    }

    mapping(address => UserInfo) internal _userInfo;

    constructor(
        address _busdToken,
        address _getlinksToken,
        address _treasuryAddress,
        uint256 _startTime,
        uint256 _endTime
    ) {
        require(
            _busdToken != address(0) &&
                _getlinksToken != address(0) &&
                _treasuryAddress != address(0),
            "Presale: Cannot be zero address"
        );
        require(block.timestamp < _startTime && _startTime < _endTime, "Presale: Time");

        busdToken = IERC20(_busdToken);
        getlinksToken = IERC20(_getlinksToken);
        treasuryAddress = _treasuryAddress;
        startTime = _startTime;
        endTime = _endTime;
    }

    function increaseSupply(uint256 amount) external onlyBeforeStartTime {
        getlinksToken.safeTransferFrom(msg.sender, address(this), amount);
        totalSupply += amount;

        emit TotalSupplyIncreased(msg.sender, amount, totalSupply);
    }

    function fund(uint256 amount) external onlyDuringPresalePeriod {
        busdToken.safeTransferFrom(msg.sender, address(this), amount);
        _userInfo[msg.sender].fundInUsd += amount;
        totalFundInUsd += amount;

        emit Fund(msg.sender, amount);
    }

    function claim() external onlyAfterEndTime {
        require(_userInfo[msg.sender].isClaimed == false, "Presale: Claimed");

        (uint256 getlinks, uint256 usd) = claimAmountOf(msg.sender);
        _userInfo[msg.sender].isClaimed = true;

        getlinksToken.safeTransfer(msg.sender, getlinks);
        if (usd > 0) {
            busdToken.safeTransfer(msg.sender, usd);
        }

        emit Claim(msg.sender, getlinks, usd);
    }

    function transferTokenToTreasury() external onlyOwner onlyAfterEndTime {
        require(isTransferredToTreasury == false, "Presale: Transferred");
        isTransferredToTreasury = true;

        (uint256 getlinks, uint256 usd) = _transferTokenToTreasury(
            totalSupply,
            totalFundInUsd,
            presaleRate
        );

        getlinksToken.safeTransfer(treasuryAddress, getlinks);
        busdToken.safeTransfer(treasuryAddress, usd);

        emit TransferredToTreasury(msg.sender, treasuryAddress, getlinks, usd);
    }

    // view function
    function claimAmountOf(address user)
        public
        view
        returns (uint256 getlinks, uint256 usd)
    {
        return
            _claimAmountOf(
                totalSupply,
                totalFundInUsd,
                presaleRate,
                _userInfo[user].fundInUsd
            );
    }

    function userInfoOf(address user) external view returns (UserInfo memory) {
        return _userInfo[user];
    }

    // internal function
    function _claimAmountOf(
        uint256 _totalSupply,
        uint256 _totalFundInUsd,
        uint256 _presaleRate,
        uint256 _userFundInUsd
    ) internal pure returns (uint256 getlinks, uint256 usd) {
        uint256 _userFundInGetlinks = _userFundInUsd * _presaleRate;
        uint256 _totalFundInGetlinks = _totalFundInUsd * _presaleRate;

        if (_totalSupply >= _totalFundInGetlinks) {
            return (_userFundInGetlinks, 0);
        }

        getlinks = (_totalSupply * _userFundInGetlinks) / _totalFundInGetlinks;
        usd = (_userFundInGetlinks - getlinks) / _presaleRate;
    }

    function _transferTokenToTreasury(
        uint256 _totalSupply,
        uint256 _totalFundInUsd,
        uint256 _presaleRate
    ) internal pure returns (uint256 getlinks, uint256 usd) {
        uint256 _totalFundInGetlinks = _totalFundInUsd * _presaleRate;
        if (_totalSupply <= _totalFundInGetlinks) {
            usd = _totalSupply / _presaleRate;
            return (0, usd);
        }

        getlinks = _totalSupply - _totalFundInGetlinks;
        usd = _totalFundInUsd;
    }

    modifier onlyBeforeStartTime() {
        require(
            block.timestamp < startTime,
            "Presale: only before the start time"
        );
        _;
    }

    modifier onlyDuringPresalePeriod() {
        require(
            block.timestamp >= startTime && block.timestamp < endTime,
            "Presale: Only during the pre-sale period"
        );
        _;
    }

    modifier onlyAfterEndTime() {
        require(
            block.timestamp >= endTime,
            "Presale: Only after the end time"
        );
        _;
    }
}

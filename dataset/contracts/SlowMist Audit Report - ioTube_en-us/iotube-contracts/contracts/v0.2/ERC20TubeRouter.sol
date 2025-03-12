// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface ITube {
    function depositTo(
        address _token,
        uint256 _amount,
        uint256 _targetTubeID,
        address _to
    ) external;

    function fees(uint256 _tubeID) external view returns (uint256);

    function tubeToken() external view returns (IERC20);
}

interface ICrosschainERC20V2Pair {
    function calculateDepositValues(uint256 _amount) external view returns (uint256, uint256);
    function deposit(uint256 _amount) external returns (uint256, uint256);
    function token() external view returns (IERC20);
    function crosschainToken() external view returns (IERC20);
}

contract ERC20TubeRouter is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    event RelayFeeReceipt(address indexed user, address indexed token, uint256 indexed targetTubeID, uint256 amount);

    struct Setting {
        bool exists;
        uint256 fee;
    }
    mapping(uint256 => Setting) public settings;
    address payable public safe;
    ITube public tube;

    constructor(ITube _tube, address payable _safe) {
        tube = _tube;
        safe = _safe;
    }

    function setRelayFee(uint256 _tubeID, bool _active, uint256 _fee) external onlyOwner {
        settings[_tubeID] = Setting(_active, _fee);
    }

    function setSafe(address payable _safe) external onlyOwner {
        safe = _safe;
    }

    function depositToWithToken(
        address _crosschainERC20Pair,
        uint256 _amount,
        uint256 _tubeID,
        address _recipient
    ) external payable nonReentrant {
        Setting memory setting = settings[_tubeID];
        require(setting.exists, "destination is inactive");
        if (setting.fee > 0) {
            require(msg.value >= setting.fee, "insufficient relay fee");
            safe.transfer(msg.value);
        }

        ICrosschainERC20V2Pair pair = ICrosschainERC20V2Pair(_crosschainERC20Pair);
        IERC20 token = pair.token();
        require(address(token) != address(0), "invalid token");
        (uint256 chargeAmount, uint256 mintAmount) = pair.calculateDepositValues(_amount);
        token.safeTransferFrom(msg.sender, address(this), chargeAmount);
        token.safeApprove(_crosschainERC20Pair, chargeAmount);
        (uint256 inAmount, uint256 outAmount) = pair.deposit(chargeAmount);
        require(inAmount == chargeAmount && outAmount == mintAmount, "invalid status");

        IERC20 crosschainToken = pair.crosschainToken();
        crosschainToken.safeApprove(address(tube), mintAmount);
        tube.depositTo(address(crosschainToken), mintAmount, _tubeID, _recipient);
        emit RelayFeeReceipt(msg.sender, address(crosschainToken), _tubeID, setting.fee);
    }

    function depositTo(
        address _crosschainToken,
        uint256 _amount,
        uint256 _tubeID,
        address _recipient
    ) external payable nonReentrant {
        Setting memory setting = settings[_tubeID];
        require(setting.exists, "destination is inactive");
        if (setting.fee > 0) {
            require(msg.value >= setting.fee, "insufficient relay fee");
            safe.transfer(msg.value);
        }

        IERC20(_crosschainToken).safeTransferFrom(msg.sender, address(this), _amount);
        IERC20(_crosschainToken).safeApprove(address(tube), _amount);
        tube.depositTo(_crosschainToken, _amount, _tubeID, _recipient);
        emit RelayFeeReceipt(msg.sender, _crosschainToken, _tubeID, setting.fee);
    }

    function withdrawCoin(address payable _to) external onlyOwner {
        Address.sendValue(_to, address(this).balance);
    }

    function withdrawToken(address _to, IERC20 _token) external onlyOwner {
        uint256 balance = _token.balanceOf(address(this));
        if (balance > 0) {
            _token.safeTransfer(_to, balance);
        }
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface ITube {
    function depositTo(
        uint256 _tubeID,
        address _token,
        address _to,
        uint256 _amount,
        bytes memory _data
    ) external;

    function depositNFTTo(
        uint256 _tubeID,
        address _token,
        uint256 _tokenID,
        address _to,
        bytes memory _data
    ) external;

    function fees(uint256 _tubeID) external view returns (uint256);

    function lord() external view returns (address);

    function tubeToken() external view returns (IERC20);
}

contract TubeRouter is Ownable {
    using SafeERC20 for IERC20;
    event RelayFeeReceipt(address user, uint256 amount);
    struct RelayFee {
        uint256 fee;
        bool exists;
    }
    mapping(uint256 => RelayFee) private relayFees;
    address private lord;
    ITube public tube;

    constructor(ITube _tube) {
        tube = _tube;
        lord = _tube.lord();
    }

    function setRelayFee(uint256 _tubeID, uint256 _fee) public onlyOwner {
        if (_fee == 0) {
            relayFees[_tubeID].exists = false;
        } else {
            relayFees[_tubeID] = RelayFee(_fee, true);
        }
    }

    function relayFee(uint256 _tubeID) public view returns (uint256) {
        require(relayFees[_tubeID].exists, "not supported");
        return relayFees[_tubeID].fee;
    }

    function depositTo(
        uint256 _tubeID,
        address _token,
        address _recipient,
        uint256 _amount,
        bytes memory _data
    ) public payable {
        uint256 fee = relayFee(_tubeID);
        require(msg.value >= fee, "insufficient relay fee");
        uint256 tubeFee = tube.fees(_tubeID);
        if (tubeFee > 0) {
            IERC20 tubeToken = tube.tubeToken();
            tubeToken.safeTransferFrom(msg.sender, address(this), tubeFee);
            tubeToken.safeApprove(address(tube), _amount);
        }
        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
        IERC20(_token).safeApprove(lord, _amount);
        tube.depositTo(_tubeID, _token, _recipient, _amount, _data);
        emit RelayFeeReceipt(msg.sender, msg.value);
    }

    function depositNFTTo(
        uint256 _tubeID,
        address _token,
        uint256 _tokenID,
        address _recipient,
        bytes memory _data
    ) public payable {
        uint256 fee = relayFee(_tubeID);
        require(msg.value >= fee, "insufficient relay fee");
        IERC721(_token).safeTransferFrom(msg.sender, address(this), _tokenID);
        IERC721(_token).approve(address(tube), _tokenID);
        tube.depositNFTTo(_tubeID, _token, _tokenID, _recipient, _data);
    }

    function withdrawCoin(address payable _to) external onlyOwner {
        _to.transfer(address(this).balance);
    }

    function withdrawToken(address _to, IERC20 _token) external onlyOwner {
        uint256 balance = _token.balanceOf(address(this));
        if (balance > 0) {
            _token.safeTransfer(_to, balance);
        }
    }
}

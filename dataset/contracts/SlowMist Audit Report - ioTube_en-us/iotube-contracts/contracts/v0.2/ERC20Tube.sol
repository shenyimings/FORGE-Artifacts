// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import "./EmergencyOperator.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface ILedger {
    function get(bytes32 _key) external view returns (uint256);
    function record(bytes32 _key) external;
}

interface ILord {
    function mint(address _token, address _recipient, uint256 _amount) external;
}

interface IBurnableERC20 {
    function burnFrom(address _owner, uint256 _amount) external;
}

interface IVerifier {
    function verify(bytes32 _key, bytes memory _signatures)
        external
        view
        returns (bool isValid_, address[] memory validators_);
}

contract ERC20Tube is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    event LordUpdated(address indexed lord);
    event SafeUpdated(address indexed safe);
    event TubeInfoUpdated(uint256 tubeID, uint256 feeRate, bool enabled);
    event Settled(bytes32 indexed key, address[] validators);
    event Receipt(
        uint256 indexed nonce,
        address sender,
        address indexed token,
        uint256 amount,
        uint256 indexed targetTubeID,
        address recipient,
        uint256 fee
    );
    struct TubeInfo {
        uint256 rate;
        bool enabled;
    }

    EmergencyOperator public emergencyOperator;
    uint256 public tubeID;
    ILedger public ledger;
    ILord public lord;
    IVerifier public verifier;
    address public safe;
    uint256 public nonce;
    mapping(uint256 => TubeInfo) private tubeInfos;

    constructor(
        uint256 _tubeID,
        ILedger _ledger,
        ILord _lord,
        IVerifier _verifier,
        address _safe,
        uint256 _initNonce,
        address _emergencyOperator
    ) ReentrancyGuard() {
        tubeID = _tubeID;
        ledger = _ledger;
        lord = _lord;
        emit LordUpdated(address(_lord));
        verifier = _verifier;
        safe = _safe;
        emit SafeUpdated(address(_safe));
        nonce = _initNonce;
        emergencyOperator = EmergencyOperator(_emergencyOperator);
    }

    function destinationTubeInfo(uint256 _tubeID) public view returns (TubeInfo memory) {
        return tubeInfos[_tubeID];
    }

    function depositTo(
        address _token,
        uint256 _amount,
        uint256 _targetTubeID,
        address _to
    ) public nonReentrant whenNotPaused {
        require(_to != address(0), "invalid recipient");
        require(_amount > 0, "invalid amount");
        // TODO: a whitelist of token?
        TubeInfo memory dst = tubeInfos[_targetTubeID];
        require(dst.enabled, "invalid destination");
        uint256 fee = 0;
        if (dst.rate > 0) {
            fee = _amount * dst.rate / 10000;
            if (fee > 0) {
                _amount -= fee;
                IERC20(_token).safeTransferFrom(msg.sender, safe, fee);
            }
        }
        IBurnableERC20(_token).burnFrom(msg.sender, _amount);
        emit Receipt(nonce++, msg.sender, _token, _amount, _targetTubeID, _to, fee);
    }

    function deposit(
        address _token,
        uint256 _amount,
        uint256 _targetTubeID
    ) public {
        depositTo(_token, _amount, _targetTubeID, msg.sender);
    }

    function genKey(
        uint256 _srcTubeID,
        uint256 _nonce,
        address _token,
        address _recipient,
        uint256 _amount
    ) public view returns (bytes32) {
        return keccak256(abi.encodePacked(_srcTubeID, _nonce, tubeID, _token, _amount, _recipient));
    }

    function isSettled(bytes32 key) public view returns (bool) {
        return ledger.get(key) != 0;
    }

    function withdraw(
        uint256 _srcTubeID,
        uint256 _nonce,
        address _token,
        address _recipient,
        uint256 _amount,
        bytes memory _signatures
    ) public nonReentrant whenNotPaused {
        require(_amount != 0, "amount is 0");
        require(_recipient != address(0), "invalid recipient");
        require(_signatures.length % 65 == 0, "invalid signature length");
        bytes32 key = genKey(_srcTubeID, _nonce, _token, _recipient, _amount);
        ledger.record(key);
        (bool isValid, address[] memory signers) = verifier.verify(key, _signatures);
        require(isValid, "insufficient validators");
        lord.mint(_token, _recipient, _amount);
        emit Settled(key, signers);
    }

    function setDestinationTube(uint256 _tubeID, uint256 _feeRate, bool _enabled) public onlyOwner {
        require(_feeRate <= 10000, "invalid fee rate");
        tubeInfos[_tubeID] = TubeInfo(_feeRate, _enabled);
        emit TubeInfoUpdated(_tubeID, _feeRate, _enabled);
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

    function setLord(ILord _lord) external onlyOwner {
        lord = _lord;
        emit LordUpdated(address(_lord));
    }

    function setSafe(address _safe) external onlyOwner {
        safe = _safe;
        emit SafeUpdated(_safe);
    }

    function pause() public {
        require(emergencyOperator.isEmergencyOperator(msg.sender), "no permission");
        _pause();
    }

    function unpause() public {
        require(emergencyOperator.isEmergencyOperator(msg.sender), "no permission");
        _unpause();
    }
}

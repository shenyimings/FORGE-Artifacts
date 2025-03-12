//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../modules/admin/Authorization.sol";
import "../../modules/kkub/interfaces/IKKUB.sol";
import "../../modules/kap20/interfaces/IKAP20.sol";
import "../../modules/kap20/interfaces/IKToken.sol";
import "../../modules/kyc/interfaces/IKYC.sol";
import "./interfaces/IAdminKAP20Router.sol";
import "./libraries/EnumerableSetAddress.sol";

abstract contract AdminKAP20Router is Authorization, IAdminKAP20Router {
    using EnumerableSetAddress for EnumerableSetAddress.AddressSet;

    EnumerableSetAddress.AddressSet private _allowedAddr;

    IKKUB public KKUB;

    IKYC public KYC;
    uint256 public bitkubNextLevel;

    address public feeTo;
    address public committee;

    event InternalTokenTransfer(address indexed _token, address indexed _from, address indexed _to, uint256 _amount);
    event ExternalTokenTransfer(address indexed _token, address indexed _from, address indexed _to, uint256 _amount);
    event FeeTransfer(address indexed _token, address _from, address indexed _to, uint256 _amount);

    modifier onlyAllowedAddress() {
        require(_allowedAddr.contains(msg.sender), "Restricted only allowed address");
        _;
    }

    modifier onlyCommittee() {
        require(committee == msg.sender, "Restricted only committee");
        _;
    }

    receive() external payable {}

    constructor(
        address _adminRouter,
        address _committee,
        address _KKUB,
        address _KYC,
        uint256 _bitkubNextLevel
    ) Authorization(_adminRouter) {
        committee = _committee;
        KKUB = IKKUB(_KKUB);
        KYC = IKYC(_KYC);
        bitkubNextLevel = _bitkubNextLevel;
        feeTo = address(this);
    }

    //////////////////////////////////////////////////////////////////////////////////////////////////

    function setKKUB(address _KKUB) external override onlySuperAdmin {
        KKUB = IKKUB(_KKUB);
    }

    function setCommittee(address _committee) external onlyCommittee {
        committee = _committee;
    }

    function setFeeTo(address _feeTo) external onlySuperAdmin {
        feeTo = _feeTo;
    }

    function setKYC(address _KYC) external onlyCommittee {
        KYC = IKYC(_KYC);
    }

    function setBitkubNextLevel(uint256 _bitkubNextLevel) external onlyCommittee {
        bitkubNextLevel = _bitkubNextLevel;
    }

    //////////////////////////////////////////////////////////////////////////////////////////////////

    function isAllowedAddr(address _addr) external view override returns (bool) {
        return _allowedAddr.contains(_addr);
    }

    function allowedAddrLength() external view override returns (uint256) {
        return _allowedAddr.length();
    }

    function allowedAddrByIndex(uint256 _index) external view override returns (address) {
        return _allowedAddr.at(_index);
    }

    function allowedAddrByPage(uint256 _page, uint256 _limit) external view override returns (address[] memory) {
        return _allowedAddr.get(_page, _limit);
    }

    function addAddress(address _addr) external override onlySuperAdminOrAdmin {
        require(_addr != address(0) && _addr != address(this), "Invalid address");
        require(_allowedAddr.add(_addr), "Address already exists");
    }

    function revokeAddress(address _addr) external override onlySuperAdmin {
        require(_allowedAddr.remove(_addr), "Address does not exist");
    }

    //////////////////////////////////////////////////////////////////////////////////////////////////

    function withdrawToken(
        address _token,
        address _to,
        uint256 _amount
    ) external onlySuperAdmin returns (bool) {
        return IKAP20(_token).transfer(_to, _amount);
    }

    function withdrawKUB(address _to, uint256 _amount) external onlySuperAdmin {
        payable(_to).transfer(_amount);
    }

    function internalTransfer(
        address _token,
        address _feeToken,
        address _from,
        address _to,
        uint256 _value,
        uint256 _feeValue
    ) external override onlyAllowedAddress returns (bool) {
        _feeTransfer(_feeToken, _from, _feeValue);
        emit InternalTokenTransfer(_token, _from, _to, _value);
        return IKToken(_token).internalTransfer(_from, _to, _value);
    }

    function externalTransfer(
        address _token,
        address _feeToken,
        address _from,
        address _to,
        uint256 _value,
        uint256 _feeValue
    ) external override onlyAllowedAddress returns (bool) {
        _feeTransfer(_feeToken, _from, _feeValue);
        emit ExternalTokenTransfer(_token, _from, _to, _value);
        return IKToken(_token).externalTransfer(_from, _to, _value);
    }

    function internalTransferKKUB(
        address _feeToken,
        address _from,
        address _to,
        uint256 _value,
        uint256 _feeValue
    ) external override onlyAllowedAddress returns (bool) {
        require(
            KYC.kycsLevel(_from) >= bitkubNextLevel && KYC.kycsLevel(_to) >= bitkubNextLevel,
            "Only internal purpose"
        );

        _feeTransfer(_feeToken, _from, _feeValue);
        emit InternalTokenTransfer(address(KKUB), _from, _to, _value);
        return IKAP20(address(KKUB)).transferFrom(_from, _to, _value);
    }

    function externalTransferKKUB(
        address _feeToken,
        address _from,
        address _to,
        uint256 _value,
        uint256 _feeValue
    ) external override onlyAllowedAddress returns (bool) {
        require(KYC.kycsLevel(_from) >= bitkubNextLevel, "Only internal purpose");

        _feeTransfer(_feeToken, _from, _feeValue);
        emit ExternalTokenTransfer(address(KKUB), _from, _to, _value);
        return IKAP20(address(KKUB)).transferFrom(_from, _to, _value);
    }

    function externalTransferKKUBToKUB(
        address _feeToken,
        address _from,
        address _to,
        uint256 _value,
        uint256 _feeValue
    ) external override onlyAllowedAddress returns (bool) {
        require(KYC.kycsLevel(_from) >= bitkubNextLevel, "Only internal purpose");

        _feeTransfer(_feeToken, _from, _feeValue);
        IKAP20(address(KKUB)).transferFrom(_from, address(this), _value);
        KKUB.withdraw(_value);
        payable(_to).transfer(_value);
        emit ExternalTokenTransfer(address(KKUB), _from, _to, _value);
        return true;
    }

    function _feeTransfer(
        address _feeToken,
        address _from,
        uint256 _feeValue
    ) internal {
        if (_feeValue > 0) {
            if (_feeToken == address(KKUB)) {
                require(IKAP20(address(KKUB)).transferFrom(_from, feeTo, _feeValue));
            } else {
                require(IKToken(_feeToken).externalTransfer(_from, feeTo, _feeValue));
            }

            emit FeeTransfer(_feeToken, _from, feeTo, _feeValue);
        }
    }
}
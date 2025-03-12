// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts-ethereum-package/contracts/access/Ownable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";

import "../interfaces/IReferral.sol";

contract HopeReferral is OwnableUpgradeSafe, IReferral {
    using SafeMath for uint256;

    mapping(address => address) public referral;
    mapping(address => bool) public authorities;
    mapping(address => address[]) public referralOf;
    mapping(address => mapping(address => uint256)) public referralEarned;
    mapping(address => uint256) public totalEarned;

    event Affiliate(address indexed referrer, address indexed referee);
    event Commission(address indexed referrer, address indexed referee, uint256 amount);

    modifier isAuthorised() {
        require(authorities[msg.sender], "!authorised");
        _;
    }

    function initialize() public initializer {
        OwnableUpgradeSafe.__Ownable_init();
    }

    function addAuthority(address authority) external onlyOwner {
        authorities[authority] = true;
    }

    function removeAuthority(address authority) external onlyOwner {
        authorities[authority] = false;
    }

    function set(address _from, address _to) external override isAuthorised {
        if (
            _from != address(0x0) &&
            _to != address(0x0) &&
            _from != _to &&
            referral[_to] == address(0x0)
        ) {
            referral[_to] = _from;
            referralOf[_from].push(_to);
            emit Affiliate(_from, _to);
        }
    }

    function onHopeCommission(address _from, address _to, uint256 _hopeAmount) external override isAuthorised {
        referralEarned[_from][_to] = referralEarned[_from][_to].add(_hopeAmount);
        totalEarned[_from] = totalEarned[_from].add(_hopeAmount);
        emit Commission(_from, _to, _hopeAmount);
    }

    function refOf(address _to) public view override returns (address) {
        return referral[_to];
    }

    function numberReferralOf(address add) external view returns (uint256) {
        return referralOf[add].length;
    }
}

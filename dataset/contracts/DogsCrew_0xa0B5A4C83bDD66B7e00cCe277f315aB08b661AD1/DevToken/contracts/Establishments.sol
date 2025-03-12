// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./Ownable.sol";
import "./SafeMath.sol";

contract Establishments is Ownable {
    using SafeMath for uint256;

    struct establishmentInfo {
        string name;
        string imagen;
        uint256 fee;
        uint256 earned_tokens;
        uint256 mp_min;
        uint256 mp_max;
        uint256 win_rate;
        bool status;
    }

    mapping(uint256 => establishmentInfo) _establishments;
    uint256[] public establishmentSid;

    function registerEstablishment(
        string memory _name,
        uint256 _fee,
        uint256 _earned_tokens,
        uint256 _mp_min,
        uint256 _mp_max,
        uint256 _win_rate,
        bool _status,
        uint256 _id
    ) public onlyOwner {
        establishmentInfo storage newEstablishment = _establishments[_id];
        newEstablishment.name = _name;
        newEstablishment.fee = _fee;
        newEstablishment.earned_tokens = _earned_tokens;
        newEstablishment.mp_min = _mp_min;
        newEstablishment.mp_max = _mp_max;
        newEstablishment.win_rate = _win_rate;
        newEstablishment.status = _status;
        establishmentSid.push(_id);
    }

    // update of establishments
    function updateEstablishment(
        string memory _name,
        uint256 _fee,
        uint256 _earned_tokens,
        uint256 _mp_min,
        uint256 _mp_max,
        uint256 _win_rate,
        bool _status,
        uint256 id
    ) public onlyOwner returns (bool success) {
        _establishments[id].status = false;
        _establishments[id].name = _name;
        _establishments[id].fee = _fee;
        _establishments[id].earned_tokens = _earned_tokens;
        _establishments[id].mp_min = _mp_min;
        _establishments[id].mp_max = _mp_max;
        _establishments[id].win_rate = _win_rate;
        _establishments[id].status = _status;
        return true;
    }

    // we deactivate establishment
    function deleteEstablishment(uint256 id)
        public
        onlyOwner
        returns (bool success)
    {
        _establishments[id].status = false;
        return true;
    }

    // we get the amount of registered establishment
    function getEstablishmentCount() public view returns (uint256 entityCount) {
        return establishmentSid.length;
    }

    // we get establishments
    function getEstablishment(uint256 id)
        public
        view
        returns (
            string memory,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            bool
        )
    {
        establishmentInfo storage s = _establishments[id];
        return (
            s.name,
            s.fee,
            s.earned_tokens,
            s.mp_min,
            s.mp_max,
            s.win_rate,
            s.status
        );
    }
}

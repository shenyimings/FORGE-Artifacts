//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../modules/kap20/KAP20.sol";
import "../../modules/kkub/interfaces/IKKUB.sol";

contract KKUB is KAP20, IKKUB {
    constructor(
        address committee_,
        address adminRouter_,
        address kyc_,
        uint256 acceptedKycLevel_
    )
        KAP20(
            "Wrap KUB",
            "KKUB",
            18,
            committee_,
            adminRouter_,
            kyc_,
            acceptedKycLevel_
        )
    {}

    fallback() external payable {
        deposit();
    }

    receive() external payable {
        deposit();
    }

    function deposit() public override payable whenNotPaused {
        _balances[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
        emit Transfer(address(0), msg.sender, msg.value);
    }

    function withdraw(uint256 _value) public override whenNotPaused {
        require(!blacklist[msg.sender], "Address is in the blacklist");
        _withdraw(_value, msg.sender);
    }

    function withdrawAdmin(uint256 _value, address _addr)
        public
        override
        onlySuperAdmin
    {
        _withdraw(_value, _addr);
    }

    function _withdraw(uint256 _value, address _addr) internal {
        require(_balances[_addr] >= _value);
        // require(
        //     kyc.kycsLevel(_addr) > acceptedKycLevel,
        //     "only kyc address registered with phone number can withdraw"
        // );

        _balances[_addr] -= _value;
        payable(_addr).call{value: _value}("");
        emit Withdrawal(_addr, _value);
        emit Transfer(_addr, address(0), _value);
    }
}

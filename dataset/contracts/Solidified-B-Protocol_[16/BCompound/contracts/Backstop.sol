pragma solidity ^0.5.16;

import "./User.sol";


contract Backstop {
    ComptrollerInterface comp;
    PriceOracle fakePriceOracle;
    mapping(address=>User) public userAccounts;


    constructor(ComptrollerInterface _comp, PriceOracle _fakePriceOracle) public {
        comp = _comp;
        fakePriceOracle = _fakePriceOracle;
    }

    function openUserAccount() public {
        require(userAccounts[msg.sender] == User(0), "user already has an account");
        userAccounts[msg.sender] = new User(comp, fakePriceOracle, msg.sender, address(this));
    }

    function enterUserMarket(address owner, CErc20Interface market) public {
        require(User(msg.sender) == userAccounts[owner], "enterUserMarket: invalid caller");
        EIP20Interface underlying = EIP20Interface(market.underlying());
        underlying.approve(msg.sender, uint(-1));
    }
}

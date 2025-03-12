    //SPDX-License-Identifier: MIT
    pragma solidity 0.8.5;


    // ----------------------------------------------------------------------------

    // ERC Token Standard #20 Interface

    // https://github.com/ethereum/EIPs/blob/master/EIPS/eip-20-token-standard.md

    // ----------------------------------------------------------------------------

    abstract contract ERC20Interface {

        function totalSupply() public view virtual returns (uint);

        function balanceOf(address tokenOwner) public view virtual returns (uint balance);

        function allowance(address tokenOwner, address spender) public view virtual returns (uint remaining);

        function transfer(address to, uint tokens) public virtual returns (bool success);

        function approve(address spender, uint tokens) public virtual returns (bool success);

        function transferFrom(address from, address to, uint tokens) public virtual returns (bool success);


        event Transfer(address indexed from, address indexed to, uint tokens);

        event Approval(address indexed tokenOwner, address indexed spender, uint tokens);

    }



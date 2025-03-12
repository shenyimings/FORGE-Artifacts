// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "SafeMath.sol";
import "OwnableUpgradeable.sol";

contract PumpToken is OwnableUpgradeable {
    using SafeMath for uint256;

    string public symbol;
    string public name;
    uint256 public decimals;
    uint256 public totalSupply;
    address public treasuryAddr;
    address public electionManagerAddr;

    // Stores addresses that are excluded from cannonTax
    // This includes any proposal contract & the 0xDEAD wallet
    mapping(address => bool) private _cannonTaxExcluded;
    // Percent of transaction that goes to cannon
    uint256 public cannonTax;

    mapping(address => uint256) public balances;
    mapping(address => mapping(address => uint256)) public allowed;

    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);

    function initialize() public initializer {
        symbol = "PUMP";
        name = "Pump Token";
        decimals = 18;
        totalSupply = 100 * 10**6 * 10**18;
        cannonTax = 3;
        balances[msg.sender] = totalSupply;
        emit Transfer(address(0), msg.sender, totalSupply);
        __Ownable_init();
    }

    /**
        @notice Approve an address to spend the specified amount of tokens on behalf of msg.sender
        @dev Beware that changing an allowance with this method brings the risk that someone may use both the old
             and the new allowance by unfortunate transaction ordering. One possible solution to mitigate this
             race condition is to first reduce the spender's allowance to 0 and set the desired value afterwards:
             https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
        @param _spender The address which will spend the funds.
        @param _value The amount of tokens to be spent.
        @return Success boolean
     */
    function approve(address _spender, uint256 _value) public returns (bool) {
        allowed[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    /**
        @notice Transfer tokens from one address to another
        @param _from The address which you want to send tokens from
        @param _to The address which you want to transfer to
        @param _value The amount of tokens to be transferred
        @return Success boolean
     */
    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) public returns (bool) {
        require(allowed[_from][msg.sender] >= _value, "Insufficient allowance");
        allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);
        _transfer(_from, _to, _value);
        return true;
    }

    /**
        @notice Transfer tokens to a specified address
        @param _to The address to transfer to
        @param _value The amount to be transferred
        @return Success boolean
     */
    function transfer(address _to, uint256 _value) public returns (bool) {
        _transfer(msg.sender, _to, _value);
        return true;
    }

    /**
        @notice Set the address of the PumpCannon
        @param _treasuryAddr The PumpCannon's address
     */
    function setTreasuryAddr(address _treasuryAddr) public onlyOwner {
        treasuryAddr = _treasuryAddr;
    }

    /**
        @notice Exclude a specific address from all future cannon taxes
        @param _addrToExclude The address to exclude
     */
    function excludeAddress(address _addrToExclude) public {
        require(
            msg.sender == owner() || msg.sender == electionManagerAddr,
            "Not approved to exclude"
        );
        _cannonTaxExcluded[_addrToExclude] = true;
    }

    /**
        @notice Set the address of the ElectionManager
        @param _electionManagerAddr the ElectionManager's address
     */
    function setElectionManagerAddr(address _electionManagerAddr)
        public
        onlyOwner
    {
        electionManagerAddr = _electionManagerAddr;
    }

    /**
        @notice Getter to check the current balance of an address
        @param _owner Address to query the balance of
        @return Token balance
     */
    function balanceOf(address _owner) public view returns (uint256) {
        return balances[_owner];
    }

    /**
        @notice Getter to check the amount of tokens that an owner allowed to a spender
        @param _owner The address which owns the funds
        @param _spender The address which will spend the funds
        @return The amount of tokens still available for the spender
     */
    function allowance(address _owner, address _spender)
        public
        view
        returns (uint256)
    {
        return allowed[_owner][_spender];
    }

    /** shared logic for transfer and transferFrom */
    function _transfer(
        address _from,
        address _to,
        uint256 _value
    ) internal {
        require(balances[_from] >= _value, "Insufficient balance");
        (uint256 _valueLessTax, uint256 tax) = _calculateTransactionTax(
            _from,
            _to,
            _value
        );

        balances[_from] = balances[_from].sub(_value);
        balances[_to] = balances[_to].add(_valueLessTax);
        emit Transfer(_from, _to, _valueLessTax);

        if (tax > 0) {
            balances[treasuryAddr] = balances[treasuryAddr] + tax;
            emit Transfer(_from, treasuryAddr, tax);
        }
    }

    function _calculateTransactionTax(
        address _from,
        address _to,
        uint256 _value
    ) internal returns (uint256, uint256) {
        // Excluded addresses are excluded regardless of if they are sending
        // or receiving PUMP. This is to prevent the act of voting from costing
        // the voter PUMP.
        if (_cannonTaxExcluded[_from] || _cannonTaxExcluded[_to]) {
            return (_value, 0);
        }
        uint256 taxAmount = _value.mul(cannonTax).div(10**2);
        return (_value - taxAmount, taxAmount);
    }
}

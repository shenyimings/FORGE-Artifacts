//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

contract Token {

    string public name;
    string public symbol;
    uint public totalSupply;
    uint public decimals;

    address public owner;
    address private _previousOwner;
    uint private _unlockTime;
    bool public ownershipRenounced;

    bool public deflationStatus;
    uint public deflationPercent;
    uint public deflationTotal;

    bool public tax1Status;
    uint public tax1Percent;
    uint public tax1Total;
    address public tax1Address;

    bool public tax2Status;
    uint public tax2Percent;
    uint public tax2Total;
    address public tax2Address;

    bool public tax3Status;
    uint public tax3Percent;
    uint public tax3Total;
    address public tax3Address;
    
    mapping(address => bool) private _isExcludedFromFee;
    
    mapping(address => uint) private _balances;
    mapping(address => mapping(address => uint)) private _allowed;
 
    event Transfer(address indexed from, address indexed to, uint value);
    event Approval(address indexed owner, address indexed spender, uint value);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can do this!");
        _;
    }
    
    constructor(
        string memory _name, 
        string memory _symbol, 
        uint[] memory _numbers, 
        address[] memory _addresses
    ) {
        name = _name;
        symbol = _symbol;
        decimals = _numbers[0];
        totalSupply = _numbers[1] * 10 ** decimals;

        deflationPercent = _numbers[3];
        deflationStatus = true;
        deflationTotal = 0;

        tax1Percent = _numbers[4];
        tax1Address = _addresses[1];
        tax1Total = 0;
        tax1Status = true;
 
        tax2Percent = _numbers[5];
        tax2Address = _addresses[2];
        tax2Total = 0;
        tax2Status = true;

        tax3Percent = _numbers[6];
        tax3Address = _addresses[3];
        tax3Total = 0;
        tax3Status = true;

        owner = _addresses[0];
        _previousOwner = _addresses[0];

        _balances[owner] = totalSupply;
        _isExcludedFromFee[owner] = true;
        _isExcludedFromFee[tax1Address] = true;
        _isExcludedFromFee[tax2Address] = true;
        _isExcludedFromFee[tax3Address] = true;

        ownershipRenounced = false;
        
        emit Transfer(address(0), owner, totalSupply);
        emit OwnershipTransferred(address(0), owner);
    }
    
    function balanceOf(address _owner) public view returns(uint) {
        return _balances[_owner];
    }
    
    function transfer(address _to, uint _value) public returns(bool) {
        require(_balances[msg.sender] >= _value, "Balance is too low");
        
        _balances[msg.sender] -= _value;

        if (!_isExcludedFromFee[msg.sender] && !_isExcludedFromFee[_to]) {

            uint sent = _value;

            if (deflationStatus && deflationPercent > 0) {
                uint defAmount = sent * deflationPercent / 1000;
                
                if (defAmount > 0) {
                    _value = _value - defAmount;
                    totalSupply -= defAmount;
                    deflationTotal += defAmount;
                    emit Transfer(msg.sender, address(0), defAmount);
                }
            }

            if (tax1Status && tax1Percent > 0) {
                uint tax1amount = sent * tax1Percent / 1000;
                
                if (tax1amount > 0) {
                    _value = _value - tax1amount;
                    tax1Total += tax1amount;
                    _balances[tax1Address] += tax1amount;
                    emit Transfer(msg.sender, tax1Address, tax1amount);
                }
            }

            if (tax2Status && tax2Percent > 0) {
                uint tax2amount = sent * tax2Percent / 1000;
                
                if (tax2amount > 0) {
                    _value = _value - tax2amount;
                    tax2Total += tax2amount;
                    _balances[tax2Address] += tax2amount;
                    emit Transfer(msg.sender, tax2Address, tax2amount);
                }
            }

            if (tax3Status && tax3Percent > 0) {
                uint tax3amount = sent * tax3Percent / 1000;
                
                if (tax3amount > 0) {
                    _value = _value - tax3amount;
                    tax3Total += tax3amount;
                    _balances[tax3Address] += tax3amount;
                    emit Transfer(msg.sender, tax3Address, tax3amount);
                }
            }

        }

        _balances[_to] += _value;

        emit Transfer(msg.sender, _to, _value);
        return true;
    }
    
    function transferFrom(address _from, address _to, uint _value) public returns(bool) {
        require(_balances[_from] >= _value, "Balance is too low");
        require(_allowed[_from][msg.sender] >= _value, "Allowance is too low");
        
        _balances[_from] -= _value;
        _allowed[_from][msg.sender] -= _value;

        if (!_isExcludedFromFee[_from] && !_isExcludedFromFee[_to]) {

            uint sent = _value;

            if (deflationStatus && deflationPercent > 0) {
                uint defAmount = sent * deflationPercent / 1000;
                
                if (defAmount > 0) {
                    _value = _value - defAmount;
                    totalSupply -= defAmount;
                    deflationTotal += defAmount;
                    emit Transfer(_from, address(0), defAmount);
                }
            }

            if (tax1Status && tax1Percent > 0) {
                uint tax1amount = sent * tax1Percent / 1000;
                
                if (tax1amount > 0) {
                    _value = _value - tax1amount;
                    tax1Total += tax1amount;
                    _balances[tax1Address] += tax1amount;
                    emit Transfer(_from, tax1Address, tax1amount);
                }
            }

            if (tax2Status && tax2Percent > 0) {
                uint tax2amount = sent * tax2Percent / 1000;
                
                if (tax2amount > 0) {
                    _value = _value - tax2amount;
                    tax2Total += tax2amount;
                    _balances[tax2Address] += tax2amount;
                    emit Transfer(_from, tax2Address, tax2amount);
                }
            }

            if (tax3Status && tax3Percent > 0) {
                uint tax3amount = sent * tax3Percent / 1000;
                
                if (tax3amount > 0) {
                    _value = _value - tax3amount;
                    tax3Total += tax3amount;
                    _balances[tax3Address] += tax3amount;
                    emit Transfer(_from, tax3Address, tax3amount);
                }
            }

        }

        _balances[_to] += _value;

        emit Transfer(_from, _to, _value);
        return true;   
    }
    
    function approve(address _spender, uint _value) public returns (bool) {
        _allowed[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;   
    }
    
    function allowance(address _owner, address _spender) public view returns (uint) {
        return _allowed[_owner][_spender];
    }

    function burn(uint _amount) public {
        require(_amount <= _balances[msg.sender], "Balance is too low");
        
        totalSupply -= _amount;
        _balances[msg.sender] -= _amount;
        
        emit Transfer(msg.sender, address(0), _amount);
    }

    function burnFrom(address _from, uint _amount) public {
        require(_amount <= _balances[_from], "Balance is too low");
        require(_amount <= _allowed[_from][msg.sender], "Allowance is too low");
        
        totalSupply -= _amount;
        _balances[_from] -= _amount;
        _allowed[_from][msg.sender] -= _amount;
        
        emit Transfer(_from, address(0), _amount);
    }

    function deflationOn() public onlyOwner {
        deflationStatus = true;
    }

    function deflationOff() public onlyOwner {
        deflationStatus = false;
    }

    function setTax1Status(bool _on) public onlyOwner {
        tax1Status = _on;
    }

    function setTax2Status(bool _on) public onlyOwner {
        tax2Status = _on;
    }

    function setTax3Status(bool _on) public onlyOwner {
        tax3Status = _on;
    }

    function setAllTaxesStatus(bool _on) public onlyOwner {
        deflationStatus = _on;
        tax1Status = _on;
        tax2Status = _on;
        tax3Status = _on;
    }

    function isExcludedFromFee(address _account) public view returns(bool) {
        return _isExcludedFromFee[_account];
    }
    
    function excludeFromFee(address _account) public onlyOwner {
        _isExcludedFromFee[_account] = true;
    }
    
    function includeInFee(address _account) public onlyOwner {
        _isExcludedFromFee[_account] = false;
    }

    function renounceOwnership() public onlyOwner {
        owner = address(0);
        _previousOwner = address(0);
        ownershipRenounced = true;
        emit OwnershipTransferred(owner, address(0));
    }

    function transferOwnership(address _newOwner) public onlyOwner {
        require(_newOwner != address(0), "New owner can't be zero address. If you still want to do this use renounceOwnership function.");
        owner = _newOwner;
        _previousOwner = _newOwner;
        emit OwnershipTransferred(owner, _newOwner);
    }

    function getUnlockTime() public view returns (uint) {
        return _unlockTime;
    }
    
    function lockOwnership(uint _duration) public onlyOwner {
        _previousOwner = owner;
        owner = address(0);
        _unlockTime = block.timestamp + _duration;
        emit OwnershipTransferred(_previousOwner, address(0));
    }
    
    function unlockOwnership() public {
        require(_previousOwner == msg.sender, "You don't have permission to unlock ownership");
        require(block.timestamp > _unlockTime , "Ownership is still locked");
        owner = _previousOwner;
        emit OwnershipTransferred(owner, _previousOwner);
    }
}
// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

/**
 * @title FruitCoins
 * @dev A simple ERC20 token with customizable tax percentages.
 */
contract FruitCoins {
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    address public immutable addressA;
    address public immutable addressB;
    address public immutable addressC; // New address to receive bonus tax
    uint256 private deploymentTime;
    uint256 public constant buyTaxAPercentage = 4;
    uint256 public constant buyTaxBPercentage = 3;
    uint256 public constant buyTaxCPercentage = 5;
    uint256 public constant liquidityTaxPercentage = 3; // 3% liquidity tax
    uint256 public sellTaxAPercentage;
    uint256 public sellTaxBPercentage;
    uint256 public constant sellTaxCPercentage = 5;
    uint256 public constant burnTax = 1;

    address public constant DEX_ADDRESS =
        0x10ED43C718714eb63d5aA57B78B54704E256024E; // PancakeSwap Router Address

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    /**
     * @dev Constructor function to initialize the ERC20 token.
     * @param _name The name of the token.
     * @param _symbol The symbol of the token.
     * @param _decimals The number of decimals for token balances.
     * @param _initialSupply The initial supply of tokens.
     * @param _addressA Address for tax calculations.
     * @param _addressB Address for tax calculations.
     * @param _addressC Address for tax calculations.

 
     */
    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        uint256 _initialSupply,
        address _addressA,
        address _addressB,
        address _addressC
    ) {
        require(
            _addressA != address(0) &&
                _addressB != address(0) &&
                _addressC != address(0) ,
            " Zero Address"
        );
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        totalSupply = _initialSupply * (10**uint256(_decimals));
        addressA = _addressA;
        addressB = _addressB;
        addressC = _addressC;
        sellTaxAPercentage = 9;
        sellTaxBPercentage = 7;
        balanceOf[msg.sender] = totalSupply;
        deploymentTime = block.timestamp;
     
    }

    /**
     * @dev Function to decrease tax percentage after specific days.
     * The tax percentages are decreased at different time intervals.
     */
    function decreaseTaxPercentage() external {
        require(
            msg.sender == addressA,
            "ERC20: Only addressA can decrease tax percentage"
        );
        require(
            block.timestamp > deploymentTime + 30 days,
            "ERC20: Can not Change Tax before 30days"
        );

        // Decrease tax percentage from 10% to 4%
        // Decrease tax percentage from 7% to 3%
        sellTaxAPercentage = 4;
        sellTaxBPercentage = 3;
    }

    /**
     * @dev Internal function to handle token transfers.
     * @param _from The address transferring tokens.
     * @param _to The recipient address.
     * @param _value The amount of tokens to transfer.
     */
    function _transfer(
        address _from,
        address _to,
        uint256 _value
    ) internal {
        require(_to != address(0), "ERC20: Transfer to the zero address");
        require(balanceOf[_from] >= _value, "ERC20: Insufficient balance");

        uint256 taxAmount = 0;
        uint256 liquidityTaxAmount = 0;
        uint256 burnAmount = 0;
        uint256 totalTax = 0;

        // Check if it's a sell transaction (from non-tax address to DEX)
        bool isSellTransaction = (_from != addressA &&
            _from != addressB &&
            _from != addressC &&
            _to == DEX_ADDRESS);

        bool isBuyTransaction = (_to != addressA &&
            _to != addressB &&
            _to != addressC &&
            _from == DEX_ADDRESS);

        // Apply tax logic only for sell transactions
        if (isSellTransaction) {
            liquidityTaxAmount = (_value * liquidityTaxPercentage) / 100;
            burnAmount = (_value * burnTax) / 100; // 1% burn
            totalTax =
                sellTaxAPercentage +
                sellTaxBPercentage +
                sellTaxCPercentage;
            taxAmount = (_value * totalTax) / 100;
        }
        if (isBuyTransaction) {
            liquidityTaxAmount = (_value * liquidityTaxPercentage) / 100;
            totalTax =
                buyTaxAPercentage +
                buyTaxBPercentage +
                buyTaxCPercentage;
            taxAmount = (_value * totalTax) / 100;
        }

        uint256 transferAmount = _value -
            taxAmount -
            liquidityTaxAmount -
            burnAmount;

        balanceOf[_from] -= _value;
        balanceOf[_to] += transferAmount;

        // Apply tax only if it's a sell transaction
        if (taxAmount > 0) {
            balanceOf[addressA] += (taxAmount * 33) / 100; // Distribute taxAmount  among addressA 33%, addressB 33%, and addressC 34%
            balanceOf[addressB] += (taxAmount * 33) / 100;
            balanceOf[addressC] += (taxAmount * 34) / 100;
            emit Transfer(_from, addressA, (taxAmount * 33) / 100);
            emit Transfer(_from, addressB, (taxAmount * 33) / 100);
            emit Transfer(_from, addressC, (taxAmount * 34) / 100);
        }
        if (burnAmount > 0) {
            totalSupply -= burnAmount;
            emit Transfer(_from, address(0), burnAmount); // Burn event
        }
        if (liquidityTaxAmount > 0) {
            balanceOf[address(this)] += liquidityTaxAmount;
            emit Transfer(_from, address(this), liquidityTaxAmount);
        }

        emit Transfer(_from, _to, transferAmount);
    }

    function approve(address spender, uint256 value)
        public
        virtual
        returns (bool)
    {
        address owner = msg.sender;
        allowance[owner][spender] += value;
        emit Approval(owner, spender, value);
        return true;
    }

    function transfer(address _to, uint256 _value)
        external
        returns (bool success)
    {
        _transfer(msg.sender, _to, _value);
        return true;
    }

    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) external returns (bool success) {
        require(
            allowance[_from][msg.sender] >= _value,
            "ERC20: Insufficient allowance"
        );
        allowance[_from][msg.sender] -= _value;
        _transfer(_from, _to, _value);
        return true;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./Context.sol";
import "./Ownable.sol";
import "./Pausable.sol";
import "./Establishments.sol";
import "./SafeMath.sol";

contract DevToken is Context, Ownable, Pausable, Establishments {
    using SafeMath for uint256;

    //  Our Tokens required variables that are needed to operate everything
    uint256 private _totalSupply;
    uint8 private _decimals;
    string private _symbol;
    string private _name;

    // _balances is a mapping that contains a address as KEY and the balance of the address as the value
    mapping(address => uint256) private _balances;

    // _balances dogscrew utility token balance
    mapping(address => uint256) private dousd_balances;

    // _allowances is used to manage and control allownace An allowance is the right to use another accounts balance, or part of it
    mapping(address => mapping(address => uint256)) private _allowances;

    // Events are created below. Transfer event is a event that notify the blockchain that a transfer of assets has taken place
    event Transfer(address indexed from, address indexed to, uint256 value);

    // Blacklist that restrict swap.
    mapping(address => bool) public blacklist;

    //  Approval is emitted when a new Spender is approved to spend Tokens on the Owners account
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    constructor(
        string memory token_name,
        string memory short_symbol,
        uint8 token_decimals,
        uint256 token_totalSupply
    ) {
        _name = token_name;
        _symbol = short_symbol;
        _decimals = token_decimals;

        _totalSupply = token_totalSupply * (uint256(10)**_decimals);
        _balances[owner()] = _totalSupply;

        emit Transfer(address(0), address(this), _totalSupply);
    }

    // decimals will return the number of decimal precision the Token is deployed with
    function decimals() external view returns (uint8) {
        return _decimals;
    }

    // symbol will return the Token's symbol
    function symbol() external view returns (string memory) {
        return _symbol;
    }

    // name will return the Token's symbol
    function name() external view returns (string memory) {
        return _name;
    }

    // totalSupply will return the tokens total supply of tokens
    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    // balanceOf will return the account balance for the given account (DOGSC)
    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    // balanceOf will return the account balance for the given account (DOUSD)
    function balanceOfDogsUSD(address account) external view returns (uint256) {
        return dousd_balances[account];
    }

    // _mint will create tokens on the address inputted and then increase the total supply
    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "DevToken: cannot mint to zero address");

        // Increase total supply
        _totalSupply = _totalSupply.add(amount);

        // Add amount to the account balance using the balance mapping
        _balances[account] = _balances[account].add(amount);

        // Emit our event to log the action
        emit Transfer(address(0), account, amount);
    }

    // _burn will destroy tokens from an address inputted and then decrease total supply
    // An Transfer event will emit with receiever set to zero address
    function _burn(address account, uint256 amount) internal {
        require(
            account != address(0),
            "DevToken: cannot burn from zero address"
        );
        require(
            _balances[account] >= amount,
            "DevToken: Cannot burn more than the account owns"
        );

        // Remove the amount from the account balance
        _balances[account] = _balances[account].sub(
            amount,
            "DevToken: burn amount exceeds balance"
        );

        // Decrease totalSupply
        _totalSupply = _totalSupply.sub(amount);

        // Emit event, use zero address as reciever
        emit Transfer(account, address(0), amount);
    }

    //  burn is used to destroy tokens on an address
    function burn(address account, uint256 amount)
        public
        onlyOwner
        returns (bool)
    {
        _burn(account, amount);
        return true;
    }

    //  mint is used to create tokens and assign them to msg.sender
    function mint(address account, uint256 amount)
        public
        onlyOwner
        returns (bool)
    {
        _mint(account, amount);
        return true;
    }

    //  transfer is used to transfer funds from the sender to the recipient  This function is only callable from outside the contract. For internal usage see
    function transfer(address recipient, uint256 amount)
        external
        whenNotPaused
        returns (bool)
    {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    // _transfer is used for internal transfers
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal {
        require(sender != address(0), "DevToken: transfer from zero address");
        require(recipient != address(0), "DevToken: transfer to zero address");
        require(
            _balances[sender] >= amount,
            "DevToken: cant transfer more than your account holds"
        );

        _balances[sender] = _balances[sender].sub(
            amount,
            "DEVTOKEN: transfer amount exceeds balance"
        );

        _balances[recipient] = _balances[recipient].add(amount);

        emit Transfer(sender, recipient, amount);
    }

    //  getOwner just calls Ownables owner function.
    function getOwner() external view returns (address) {
        return owner();
    }

    //  allowance is used view how much allowance an spender has
    function allowance(address owner, address spender)
        external
        view
        returns (uint256)
    {
        return _allowances[owner][spender];
    }

    // approve will use the senders address and allow the spender to use X amount of tokens on his behalf
    function approve(address spender, uint256 amount)
        external
        whenNotPaused
        returns (bool)
    {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    // _approve is used to add a new Spender to a Owners account
    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal {
        require(
            owner != address(0),
            "DevToken: approve cannot be done from zero address"
        );
        require(
            spender != address(0),
            "DevToken: approve cannot be to zero address"
        );

        // Set the allowance of the spender address at the Owner mapping over accounts to the amount
        _allowances[owner][spender] = amount;

        emit Approval(owner, spender, amount);
    }

    // transferFrom is uesd to transfer Tokens from a Accounts allowance Spender address should be the token holder
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external whenNotPaused returns (bool) {
        _transfer(sender, recipient, amount);

        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(
            currentAllowance >= amount,
            "DevToken: You cannot spend that much on this account"
        );

        _approve(sender, _msgSender(), currentAllowance.sub(amount));

        return true;
    }

    // Adds allowance to a account from the function caller address
    function increaseAllowance(address spender, uint256 addedValue)
        public
        whenNotPaused
        returns (bool)
    {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender].add(addedValue)
        );

        return true;
    }

    // Decrease the allowance on the account inputted from the caller address
    function decreaseAllowance(address spender, uint256 subtractedValue)
        public
        whenNotPaused
        returns (bool)
    {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender].sub(
                subtractedValue,
                "DEVTOKEN: decreased allowance below zero"
            )
        );

        return true;
    }

    // GAME

    // Start and stop swap
    bool public swapActive = true;

    // Start and stop Attack
    bool public attackActive = true;

    // tokens busd for dogsc
    uint256 public swapAmount = 1;

    // change percentage of crew damaged
    uint256 public percentageOfCrewDamaged = 25;

    // early withdrawal penalty
    uint256 public penalty = 75;

    // ramdom number generator
    uint256 randNonce = 0;

    // winner struct
    struct winnerStruct {
        uint256 earned_tokens;
        uint256 win_rate;
        uint256 winner;
        bool damaged_crew;
        bool status;
    }

    // Attack struct
    event EventSendAttack(
        address attack_you,
        uint256 earned_tokens,
        uint256 win_rate,
        uint256 winner,
        bool damaged_crew,
        bool status
    );

    // event emit
    event EventLifeContract(
        address attack_you,
        string idCrew,
        uint256 amounttoken,
        bool status
    );
    // from DOUSD -> DOGSC
    event _swapDOUSDfromDOGSC(
        address buyer,
        uint256 dogsc,
        uint256 dousd,
        bool discount
    );

    // Edit reserved whitelist spots
    function editBlackList(address _address, bool _block)
        public
        onlyOwner
    {
        blacklist[_address] = _block;
    }

    // check if your account is blocked
    function blockedAccount(address _address) public view returns (bool) {
        return blacklist[_address];
    }

    //  we change utility token (DOUSD) of the game for dogs (DOGS) /  DOUSD -> DOGSC
    function swaDOUSDFromDOGSC(uint256 tokenAmountToDOUSD, bool discount)
        public
        whenNotPaused
        returns (bool)
    {
        // verificamos que le swap este activo
        require(swapActive, "swap isn't active");

        // check if your account is blocked
        bool isBlocked = blacklist[_msgSender()];
        require(!isBlocked, "Your account is blocked");

        // Check that the requested amount of tokens to sell is more than 0
        require(
            tokenAmountToDOUSD > 0,
            "Specify an amount of token greater than zero"
        );

        // Check that the user's token balance is enough to do the swap
        uint256 userBalance = dousd_balances[_msgSender()];
        require(
            userBalance >= tokenAmountToDOUSD,
            "Your balance is lower than the amount of tokens you want to sell"
        );

        // quemo los token de utilidad (DOUSD)
        dousd_balances[_msgSender()] = dousd_balances[_msgSender()].sub(
            tokenAmountToDOUSD
        );

        uint256 amount = 0;
        if (discount) {
            uint256 _amount = tokenAmountToDOUSD * swapAmount;
            amount = (_amount * penalty) / 100;
        } else {
            amount = tokenAmountToDOUSD * swapAmount;
        }

        // Transfer token to the msg.sender
        _mint(_msgSender(), amount);

        // emitimos el evento
        emit _swapDOUSDfromDOGSC(
            _msgSender(),
            tokenAmountToDOUSD,
            amount,
            discount
        );

        return true;
    }

    // receives tokens for the operation of the game dynamics (DOGSC)
    function lifeContracts(uint256 tokenAmount, string memory idCrew)
        public
        returns (bool)
    {
        require(attackActive, "attack isn't active");

        // verifico que tenga token suficientes
        uint256 userBalance = _balances[_msgSender()];
        require(
            userBalance >= tokenAmount,
            "Your balance is lower than the amount of tokens you want to sell"
        );

        // le enviamos los tokens al contrato
        _balances[address(this)] = _balances[address(this)].add(tokenAmount);

        // quemamos los toke del sender
        _burn(_msgSender(), tokenAmount);

        emit EventLifeContract(_msgSender(), idCrew, tokenAmount, true);
        return true;
    }

    // function to choose a winner in the attack
    function sendAttack(uint256 establishmentId, uint256 crewLife)
        public
        payable
        returns (winnerStruct memory _propertyObj)
    {
        require(msg.value > 0, "Send BNB to buy some tokens");

        // verificamos que le swap este activo
        require(attackActive, "attack isn't active");

        uint256 userBalance = _balances[_msgSender()];

        // debe tener minimo un token de dogs
        require(userBalance >= 1, "you have to have minimum 1 dogs to attack");

        // obtenemos los datos de estableciemiento
        establishmentInfo storage s = _establishments[establishmentId];

        // tiene que enviar fee
        require(msg.value >= s.fee, "Send BNB to buy some tokens (FEE)");

        // verificamos que no esta cerrado
        require(s.status, "closed establishment");

        //  ejecutamaos el metodo que determina quien gana
        uint256 winner = randMod(100);
        // verificamos si la crew sufre danos
        bool damaged_crew = winner <= percentageOfCrewDamaged ? true : false;

        uint256 earned_tokens = 0;

        // si gana entra en este if
        if (winner <= s.win_rate) {
            // le pasamos los dogsUSd al balance del sender
            earned_tokens = calculateProfit(crewLife, s.earned_tokens);

            // le pasamos los dogsUSd al balance del sender
            dousd_balances[_msgSender()] = dousd_balances[_msgSender()].add(
                earned_tokens
            );

            // emitimos un evento
            emit EventSendAttack(
                _msgSender(),
                earned_tokens,
                s.win_rate,
                winner,
                damaged_crew,
                true
            );
            return
                winnerStruct(
                    earned_tokens,
                    winner,
                    s.win_rate,
                    damaged_crew,
                    true
                );
        }

        // emitimos el evento
        emit EventSendAttack(
            _msgSender(),
            earned_tokens,
            s.win_rate,
            winner,
            damaged_crew,
            false
        );
    }

    function calculateProfit(uint256 crewLife, uint256 earned_tokens)
        internal
        pure
        returns (uint256)
    {
        if (crewLife == 100) {
            return earned_tokens;
        }
        return (earned_tokens * crewLife) / 100;
    }

    // Defining a function to generate
    // a random number
    function randMod(uint256 _modulus) public returns (uint256) {
        // increase nonce
        randNonce++;
        return
            uint256(
                keccak256(
                    abi.encodePacked(block.timestamp, msg.sender, randNonce)
                )
            ) % _modulus;
    }

    // Start and stop Attack
    function setAttackActive(bool val) public onlyOwner {
        attackActive = val;
    }

    // Start and stop swap
    function setSwapActive(bool val) public onlyOwner {
        swapActive = val;
    }

    // change price swap
    function setPriceSwapActive(uint256 val) public onlyOwner {
        swapAmount = val;
    }

    // change percentage of crew damaged
    function changePercentageDamaged(uint256 val) public onlyOwner {
        percentageOfCrewDamaged = val;
    }

    // change early withdrawal penalty
    function changePenalty(uint256 val) public onlyOwner {
        penalty = val;
    }

    /**
     * @notice Allow the owner of the contract to withdraw BNB
     */
    function withdraw() public onlyOwner {
        uint256 ownerBalance = address(this).balance;
        require(ownerBalance > 0, "Owner has not balance to withdraw");

        (bool sent, ) = _msgSender().call{value: address(this).balance}("");
        require(sent, "Failed to send user balance back to the owner");
    }
}

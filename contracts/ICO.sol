// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.5.6;


interface ERC20Interface {
    function transfer(address to, uint tokens) external returns (bool success);
    function transferFrom(address from, address to, uint tokens) external returns (bool success);
    function balanceOf(address tokenOwner) external view returns (uint balance);
    function approve(address spender, uint tokens) external returns (bool success);
    function allowance(address tokenOwner, address spender) external view returns (uint remaining);
    function totalSupply() external view returns (uint);

    event Transfer(address indexed from, address indexed to, uint tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
}
contract ERC20Token is ERC20Interface{
    // optional variables
    string public name;
    string public symbol;
    uint8 public decimals;
    // required variables
    uint public totalSupply;
    mapping(address => uint) public balances; //uint is the balance for an address
    // first address is token holder; second address is the third party approved to transferFrom; uint is
    // the maximum # of tokens that this third party can transfer on behalf of the token holder
    mapping(address => mapping(address => uint)) public allowed;

    constructor(string memory _name,
        string memory _symbol,
        uint8 _decimals,
        uint _totalSupply) public {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        totalSupply = _totalSupply;
        balances[msg.sender] = _totalSupply;// give all the tokens to the guy that creates this contract
    }
    function transfer(address to, uint value) public returns(bool){
        require(balances[msg.sender] >= value, 'token balance too low');
        balances[msg.sender] -= value;
        balances[to] += value;
        emit Transfer(msg.sender, to, value);
        return true;
    }
    function transferFrom(address from, address to, uint value) public returns(bool){
        uint allowance = allowed[from][msg.sender];
        // msg.sender is sending HIS tokens ON BEHALF OF from; not sending FROMs tokens
        require(balances[msg.sender] >= value && allowance >= value, 'not enough tokens in your allowance to transfer');
        //decrease the allowed from msg.sender
        allowed[from][msg.sender] -= value;
        balances[msg.sender] -= value;
        balances[to] += value;
        emit Transfer(msg.sender, to, value);
        return true;
    }
    function balanceOf(address owner) public view returns(uint) {
        return balances[owner];
    }
    function approve(address spender, uint value) public returns (bool){
        require(spender != msg.sender,'cannot approve of yourself');
        allowed[msg.sender][spender] = value; // increase the allowance
        emit Approval(msg.sender, spender, value);
        return true;
    }
    function allowance(address owner, address spender) public view returns (uint){
        return allowed[owner][spender];
    }
}
contract ICO {
    struct Sale {
        address investor;
        uint quantity;
    }
    Sale[] public sales;
    mapping(address => bool) investors;
    address public token;
    address public admin;
    uint public end; //date of the end of this ICO
    uint public price; //cost of a token in wei or ether
    uint public availableTokens;
    uint public minPurchase; // cover costs of KYC
    uint public maxPurchase; // diversification of investors; to stop too much power
    bool public released = false;

    constructor(string memory _name,
        string memory _symbol,
        uint8 _decimals,
        uint _totalSupply) public {
        token = address(new ERC20Token(_name,_symbol,_decimals,_totalSupply));
        admin = msg.sender;
    }
    function start(uint duration, uint _price, uint _availableTokens,
        uint _minPurchase, uint _maxPurchase) external onlyAdmin() icoNotActive(){
        require(duration > 0, 'duration should be greater than 0');
        uint totalSupply = ERC20Token(token).totalSupply();
        require(_availableTokens > 0 && _availableTokens <= totalSupply, 'total supply should be > 0 and < total supply');
        require(_minPurchase > 0);
        require(_maxPurchase > 0 && _maxPurchase <= _availableTokens,
            'max purchase should be > 0 and <= available tokens');
        end = block.timestamp + duration; // date of end of ICO
        price = _price;
        availableTokens = _availableTokens;
        minPurchase = _minPurchase;
        maxPurchase = _maxPurchase;

    }
    function whiteList(address investor) external onlyAdmin(){
        investors[investor] = true;
    }
    function buy() payable external  onlyInvestors() icoActive(){
        require(msg.value % price != 0,'have to send a multiple of price');
        require(msg.value >= minPurchase && msg.value <= maxPurchase,'have to send amount between min and max');
        uint quantity = price * msg.value;
        require(quantity <= availableTokens,'not enough tokens left for sale');
        sales.push(Sale(
            msg.sender,
            quantity
        ));
    }
    function release() external onlyAdmin() icoEnded() tokensNotReleased(){
        ERC20Token tokenInstance = ERC20Token(token);
        for(uint i = 0; i < sales.length; i++){
            Sale storage sale = sales[i];
            tokenInstance.transfer(sale.investor, sale.quantity);
        }
        released = true;
    }
    function withdraw(address payable to, uint amount) external onlyAdmin() icoEnded()
        tokensReleased(){
        to.transfer(amount);
    }
    //Julien: I have added this function for the frontend
    function getSale(address _investor) external view returns(uint) {
        for(uint i = 0; i < sales.length; i++) {
            if(sales[i].investor == _investor) {
                return sales[i].quantity;
            }
        }
        return 0;
    }
    modifier onlyAdmin(){
        require(msg.sender == admin,'can only be performed by admin');
        _;
    }
    modifier icoNotActive(){
        require(end == 0,'ICO should not be active');
        _;
    }
    modifier icoEnded(){
        require(end > 0 && (block.timestamp >= end || availableTokens == 0),'ICO must be over');
        _;
    }
    modifier tokensReleased(){
        require(released == true,'tokens must have been released');
        _;
    }
    modifier tokensNotReleased(){
        require(released == false,'tokens must not have been released');
        _;
    }
    modifier onlyInvestors(){
        require(investors[msg.sender] == true,'only investors');
        _;
    }
    modifier icoActive(){
        require(end > 0 ,'ICO must be active');
        require(block.timestamp < end ,'ICO is over');
        require(availableTokens > 0 ,'ICO must have available tokens');
        _;
    }
}


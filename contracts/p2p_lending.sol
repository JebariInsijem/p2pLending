
pragma solidity ^0.4.16;

/**
 * @title SafeMath by OpenZeppelin
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {
  function mul(uint256 a, uint256 b) internal constant returns (uint256) {
    uint256 c = a * b;
    assert(a == 0 || c / a == b);
    return c;
  }

  function div(uint256 a, uint256 b) internal constant returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return c;
  }

  function sub(uint256 a, uint256 b) internal constant returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  function add(uint256 a, uint256 b) internal constant returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }
}


/**
 * @title ERC20 interface, by OpenZeppelin
 */
contract ERC20Token {
     function balanceOf(address who) public constant returns (uint256);
     function transfer(address to, uint256 value) public returns (bool);
     function allowance(address owner, address spender) public constant returns (uint256);
     function transferFrom(address from, address to, uint256 value) public returns (bool);
     function approve(address spender, uint256 value) public returns (bool);
}



contract LoanRecord {     
     address public mainAddress;

     uint public totalLoans = 0; 

     mapping (address => mapping(uint => address)) loanRequestsPerUser; 
     mapping (address => uint) loanCountPerUser;              
     mapping (uint => address) loanRequests; 

     
     function LoanRecord() public{
          mainAddress = msg.sender;
     }

     function getLoanCount() public constant returns(uint){ return totalLoans; }
     function getLoan(uint _index) public constant returns (address){ return loanRequests[_index]; }
     function getLoanCountForUser(address _addr) public constant returns(uint){ return loanCountPerUser[_addr]; }
     function getLoanForUser(address _addr, uint _index) public constant returns (address){ return loanRequestsPerUser[_addr][_index]; }
     
     function newLoan(uint _loanAmountInWei, uint _tokenAmount, uint _premiumAmountInWei, string _tokenName, string _tokenInfolink, address _tokenSmartContractAddress, uint _daysToLend) public returns(address){
          Loan loan = new Loan(msg.sender);
          loan.setData(_loanAmountInWei, _tokenAmount, _premiumAmountInWei, _tokenName, _tokenInfolink, _tokenSmartContractAddress, _daysToLend);
          
          uint currentCount = loanCountPerUser[msg.sender];
          loanRequestsPerUser[msg.sender][currentCount] = loan;
          loanCountPerUser[msg.sender]++;

          loanRequests[totalLoans] = loan;
          totalLoans++;

          return loan;
      }



     function getLoanFundedCount() public constant returns(uint out){
          out = 0;

          for(uint i=0; i<totalLoans; ++i){
               Loan lr = Loan(loanRequests[i]);
               if(lr.getCurrentState() == Loan.State.WaitingForPayback){
                    out++;
               }
          }

          return;
     }

     function getLoanFunded(uint index) public constant returns (address){          
          Loan lr = Loan(loanRequests[index]);
          if(lr.getCurrentState() == Loan.State.WaitingForPayback){
               return loanRequests[index];
          } else {
               return 0;
          }
     }
}

contract Loan {
     enum State {  
          Init,  
          WaitingForTokens,  
          Cancelled,         
          WaitingForLender, 
          WaitingForPayback, 
          Default,          
          Finished    
     }

     using SafeMath for uint256;            
     LoanRecord loanRecord;                        
     address public creator            = 0x0; 
     address public mainAddress        = 0x0; 

     State private currentState   = State.Init; 

     address public borrower  = 0x0;                   
     uint public loanAmountInWei   = 0;                  
     uint public premiumAmountInWei  = 0;                    
     uint public tokenAmount = 0;                     
     uint public daysToLend = 0;                       
     string public tokenName = "";                   
     string public tokenInfolink = "";              
     address public tokenSmartContractAddress = 0x0;   
     
     uint public start     = 0;    //Holds the startTime of the loan when loan Funded
     address public lender = 0x0;  


     /* Constants Methods: */
     function getLender() public constant returns(address){ return lender; }     
     function getBorrower() public constant returns(address){ return borrower; }
     function getLoanAmountInWei() public constant returns(uint){ return loanAmountInWei; }
     function getTokenName() public constant returns(string){ return tokenName; }
     function getDaysToLen() public constant returns(uint){ return daysToLend; }
     function getPremiumAmountInWei() public constant returns(uint){ return premiumAmountInWei; }
     function getTokenAmount() public constant returns(uint){ return tokenAmount; }     
     function getTokenInfoLink() public constant returns(string){ return tokenInfolink; }
     function getTokenSmartcontractAddress() public constant returns(address){ return tokenSmartContractAddress; }
    

     modifier onlyByLoanRecord(){
          require(LoanRecord(msg.sender) == loanRecord);
          _;
     }

     modifier onlyByMain(){
          require(msg.sender == mainAddress);
          _;
     }

     modifier byLoanRecordOrMain(){
          require(msg.sender == mainAddress || LoanRecord(msg.sender) == loanRecord);
          _;
     }

     modifier byLoanRecordMainOrBorrower(){
          require(msg.sender == mainAddress || LoanRecord(msg.sender) == loanRecord || msg.sender == borrower);
          _;
     }

     modifier onlyByLender(){
          require(msg.sender == lender);
          _;
     }

     modifier onlyInState(State state){
          require(getCurrentState() == state);
          _;
     }

     function Loan(address _borrower) public {
          creator = msg.sender;
          loanRecord = LoanRecord(msg.sender);

          borrower = _borrower;
          mainAddress = loanRecord.mainAddress();
     }

     function getCurrentState() public constant returns(State){
       if(currentState == State.WaitingForTokens){
            ERC20Token token = ERC20Token(tokenSmartContractAddress);

            uint tokenBalance = token.balanceOf(this);
            if(tokenBalance >= tokenAmount){
               return State.WaitingForLender;
            }else{
                return currentState;
            }
       }else{
         return currentState;
       }

     }

     function changeLoanRecordAddress(address _new) public onlyByLoanRecord{
          loanRecord = LoanRecord(_new);
     }

     function changeMainAddress(address _new) public onlyByMain{
          mainAddress = _new;
     }

     function setData(uint _loanAmountInWei, uint _tokenAmount, uint _premiumAmountInWei, string _tokenName, string _tokenInfolink, address _tokenSmartContractAddress, uint _daysToLend) public byLoanRecordMainOrBorrower onlyInState(State.Init) {
          loanAmountInWei = _loanAmountInWei;
          premiumAmountInWei = _premiumAmountInWei;
          tokenName = _tokenName;
          tokenAmount = _tokenAmount;
          tokenInfolink = _tokenInfolink;
          tokenSmartContractAddress = _tokenSmartContractAddress;
          daysToLend = _daysToLend;
          
          currentState = State.WaitingForTokens;
     }

     function cancel() public byLoanRecordMainOrBorrower {
          if((getCurrentState() != State.WaitingForTokens) && (getCurrentState() != State.WaitingForLender))
               revert();

          if(getCurrentState() == State.WaitingForLender){
               releaseToBorrower();
          }
          currentState = State.Cancelled;
     }

     function() public payable {
          if(getCurrentState() == State.WaitingForLender){
               waitingForLender();
          } else if(getCurrentState() == State.WaitingForPayback){
               waitingForPayback();
          } else {
               revert();
          }
     }

     function returnTokens() public byLoanRecordMainOrBorrower onlyInState(State.WaitingForLender){
          releaseToBorrower();
          currentState = State.Finished;
     }

     function waitingForLender() public payable onlyInState(State.WaitingForLender){
          if(msg.value < loanAmountInWei){
               revert();
          }
          lender = msg.sender;     

          borrower.transfer(loanAmountInWei);

          currentState = State.WaitingForPayback;

          start = now;
     }

     function waitingForPayback() public payable onlyInState(State.WaitingForPayback){
          if(msg.value < loanAmountInWei.add(premiumAmountInWei)){
               revert();
          }
          lender.transfer(msg.value);

          releaseToBorrower(); 
          currentState = State.Finished; 
     }

     function getNeededSumByLender() public constant returns(uint){
          return loanAmountInWei;
     }

     function getNeededSumByBorrower() public constant returns(uint){
          return loanAmountInWei.add(premiumAmountInWei);
     }

     function requestDefault() public onlyInState(State.WaitingForPayback){
          if(now < (start + daysToLend * 1 days)){
               revert();
          }

          releaseToLender(); 
          currentState = State.Default; 
     }

     function releaseToLender() internal {
          ERC20Token token = ERC20Token(tokenSmartContractAddress);
          uint tokenBalance = token.balanceOf(this);
          token.transfer(lender,tokenBalance);
     }

     function releaseToBorrower() internal {
          ERC20Token token = ERC20Token(tokenSmartContractAddress);
          uint tokenBalance = token.balanceOf(this);
          token.transfer(borrower,tokenBalance);
     }
}

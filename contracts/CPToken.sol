// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";




// Interface for CPToken contract
interface ICPToken {
    
    // Function to set a new admin for the CPToken contract
    function setNewAdmin(address _adr)  external returns(bool);
    
    // Function to remove an admin from the CPToken contract
    function removeAdmin(address _adr)  external returns(bool);

    // Function to set a new price for the token in cents
    function setNewPriceForToken(uint256 new_price_in_cent) external returns(bool);

    // Function to mint new token 
    function mintNewToken(uint256 inital_token_supply)  external returns(bool);

    // Function to allow users to buy tokens by sending tokenb to the contract
    function buyTokens(uint256 numberOfTokens) external payable returns (bool);   

    //  Burns a specified amount of tokens from the contract's supply.
    function burnToken(uint256 _amountInWei) external returns(bool);

    // Retrieves the list of administrators.
    function getAdminList()  external view returns(address[] memory);

    //  Allows any address to withdraw Ether from the contract to a specified address.
    function withdrawEth(address payable _receiver, uint256 _ethAmountInWei)  external returns(bool);

    // Set the allowance amount for a spender and return true on success
    function setAllowanceAmount(uint256 _allowanceAmount)  external returns(bool);

    // Get the allowance amount for a spender
    function getAllowanceAmount()  external view returns(uint256);

    // Set allowance status for a specific spender and return true on success
    function setAllowance(address _spender)  external returns(bool);

    // Reset allowance status for a specific spender and return true on success
    function resetAllowance(address _spender)  external returns(bool);


    // Check if the caller is an admin and return true if so
    function checkIsAdmin() external view returns(bool);
}


contract CPToken is ICPToken, ERC20 {

    // Import SafeMath library
    using SafeMath for uint256; 

    // This mapping keeps track of addresses that have admin privileges for CP tokens.
    // Admins have special rights, which can be controlled using this mapping.
     mapping(address => bool) internal CPTokenAdmin;   
    
     // The AggregatorV3Interface is used to fetch Ethereum price data.
     AggregatorV3Interface internal priceFeed; 

    /*
    * Sepolia Network Address: 0x694AA1769357215DE4FAC081bf1f309aDC325306
    * Mainnet Address: 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419
    *
    * The constant private variable ETH_PRICE_FEED_CONTRACT_ADR holds the address
    * of the Ethereum price feed contract on Sepolia Network.
    * This contract is used to obtain real-time Ethereum price data.
    */
    address constant private ETH_PRICE_FEED_CONTRACT_ADR = 0x694AA1769357215DE4FAC081bf1f309aDC325306;

    // Assuming 6 decimal places for ETH : Convert ETH price to cent
    uint256 public constant DECIMALS = 6;
    uint256 public constant PRICE_SCALING_FACTOR = 10**DECIMALS;

    // Number of decimals used for Ethereum (ETH)
    uint256 public constant ETH_DECIMALS = 18;
    
    // Scaling factor for Ethereum conversions
    uint256 public constant ETH_SCALING_DECIMALS = 10**ETH_DECIMALS;

    
    // Variable representing the constant price of 1 CPToken in cent
    uint256 public Token_Price_in_Cent;
    uint256 public Token_Price_in_Wei; 

    // Total token supply  
    uint256 public Total_Token_Supply_In_Wei;

    // Maximum Allowance 
    uint256 private Max_Allowance_Amount;

    // Admin address array
    address[] internal adminList;



    // Withdraw ETH Allowance
    mapping(address => mapping(address => bool)) private allowanceVotes;
    mapping(address => uint256) private allowanceVotesCount;
    mapping(address => uint256) private allowances;

    uint256 private numAdmins;
    uint256 private majorityThreshold;

    // Events
    event Set_Admin(address indexed adr);
    event Remove_Admin(address indexed adr);
    event Setted_New_Token_Price(address indexed adr,uint256 indexed newPrice, uint256 indexed oldPrice);
    event Change_Token_Supply(uint256 indexed oldSupply, uint256 indexed newSupply);
    event Buy_Token(address indexed buyer, uint256 indexed _amount,uint256 current_balance);
    event Allowance_Set(address indexed spender,address indexed voted_adr);
    event Allowance_Reset(address indexed spender,address indexed voted_adr);



    constructor(uint256 initial_token_price_in_cent,uint256 inital_token_supply_in_Wei,uint256 _max_allowance_amount) ERC20("AEON Token" , "AET") {
     
     // Set the price feed contract address for ETH/USD conversion   
     priceFeed = AggregatorV3Interface(ETH_PRICE_FEED_CONTRACT_ADR);
     
     // Mark the contract deployer (admin) as a CP Token admin
     CPTokenAdmin[tx.origin] = true;
     adminList.push(tx.origin);

     // Mint initial tokens to the contract deployer
     _mint(address(this), inital_token_supply_in_Wei);

 
     // Sets the total token supply to the initial value.
     Total_Token_Supply_In_Wei = inital_token_supply_in_Wei;

     // Sets the token price in cents and calculates the corresponding price in Wei.
     Token_Price_in_Cent = initial_token_price_in_cent; 

     // Calculate the token price in Wei based on the initial price in cents
     Token_Price_in_Wei = calculateTokenPriceInWei();

     // Set maximum allowance amount
     Max_Allowance_Amount = _max_allowance_amount;

      // Set Allowence vote check
       numAdmins = 1; 
       majorityThreshold = 1;

    }


    
    // Function to mint new tokens, only callable by the admin (owner)
    function mintNewToken(uint256 inital_token_supply_in_Wei) _onlyAdmin external returns(bool){
   
     // Store the current total token supply in Wei   
     uint256 oldSupply = Total_Token_Supply_In_Wei;

     // Increase the total token supply
     Total_Token_Supply_In_Wei += inital_token_supply_in_Wei;
     _mint(address(this), inital_token_supply_in_Wei);
     

     // Emit an event to log the generation of new tokens
     emit Change_Token_Supply(oldSupply,Total_Token_Supply_In_Wei);
     return true;
    }


    // Function to set a new admin for CP tokens.
    // Only existing admins can call this function, as indicated by the _onlyAdmin modifier.
    // The new admin's address is provided as an argument, and they are granted admin privileges.
    function setNewAdmin(address _adr) _onlyAdmin external returns(bool){
        require(!CPTokenAdmin[_adr] , "The address is admin already.");
        CPTokenAdmin[_adr] = true;
        adminList.push(_adr);

        // Set new allowence vote treshold
        numAdmins = numAdmins.add(1);
        majorityThreshold = (numAdmins.add(1)) / 2;

        emit Set_Admin(_adr);
        return true;
    }

    // Retrieves the list of administrators.
    function getAdminList() _onlyAdmin external view returns(address[] memory){
        // Return the array containing the addresses of administrators
        return adminList;
    }


    // Function to remove admin privileges for a specified address.
    // Requires the caller to be an existing admin (_onlyAdmin modifier).
    function removeAdmin(address _adr) _onlyAdmin external returns(bool){
        // Check if the address is not already an admin
        require(CPTokenAdmin[_adr] , "The address is not admin already.");
        
        // Revoke admin status by updating the mapping
        CPTokenAdmin[_adr] = false;

        // Find and remove the specified admin address from the adminList array
        for (uint256 i = 0; i < numAdmins; i++) {
            if (adminList[i] == _adr) {
                adminList[i] = adminList[numAdmins - 1];
                adminList.pop();
                break;
            }
        }

        // Set new allowence vote treshold
        numAdmins = numAdmins.sub(1);
        majorityThreshold = (numAdmins.add(1)) / 2;

        // Emit an event to log the removal of admin
        emit Remove_Admin(_adr);

        // Return success
        return true;
    }

     // Sets the maximum allowance amount that can be voted by admins.
    function setAllowanceAmount(uint256 _allowanceAmount) _onlyAdmin external returns(bool) {
        Max_Allowance_Amount = _allowanceAmount;
        return true;
    }


     //Retrieves the maximum allowance amount.
    function getAllowanceAmount() _onlyAdmin external view returns(uint256){
        return Max_Allowance_Amount;
    }

    //Sets an allowance for a specific spender. Only admins can perform this action.
    function setAllowance(address _spender) _onlyAdmin external returns(bool) {
        
         // Check is voted before by sender
        require(!allowanceVotes[_spender][tx.origin], "You have already voted for this allowance");

         // Check spender is admin
        require(CPTokenAdmin[_spender], "Spender must be admin!");

        // Assign set status
        allowanceVotes[_spender][tx.origin] = true; 
        allowanceVotesCount[_spender] = allowanceVotesCount[_spender].add(1);

        // Additional logic for checking majority votes can be added here
       emit Allowance_Set(_spender,tx.origin);

       return true;
    }

    //Resets the allowance for a specific spender. Only admins can perform this action.
    function resetAllowance(address _spender) _onlyAdmin external returns(bool){
        
        // Check is voted before by sender
        require(allowanceVotes[_spender][tx.origin], "You have note voted for this allowance yet");

        // Assign new reset status
        allowanceVotes[_spender][tx.origin] = false;
        allowanceVotesCount[_spender] = allowanceVotesCount[_spender].sub(1);

        // Emit the event : 
        emit Allowance_Reset(_spender,tx.origin);
        return true;
    }

    //  Allows any address to withdraw Ether from the contract to a specified address.
    function withdrawEth(address payable _receiver, uint256 _ethAmountInWei) _onlyAdmin external returns(bool){
   
    // Ensure that the withdrawal amount is not zero
    require(_ethAmountInWei > 0, "Withdrawal amount must be greater than zero");

    // Ensure that the contract has sufficient balance for withdrawal
    require(address(this).balance >= _ethAmountInWei, "Insufficient contract balance");

    // Ensure that supply the allownce conditions
    require(allowanceVotesCount[_receiver] >majorityThreshold , "Not enough allowance votes were received"); 

    // Ensure that the amount is under the maximum amount
    require(Max_Allowance_Amount >_ethAmountInWei , "Not enough allowance votes were received"); 

    // Transfer Ether to the specified address
    _receiver.transfer(_ethAmountInWei);

    return true;

    }


    // Function to set a new price for the token
    function setNewPriceForToken(uint256 new_price_in_cent) _onlyAdmin external returns(bool){
        // Store the current token price in cents for event emission
        uint256 oldPrice = Token_Price_in_Cent;

        // Update the token price in cents
        Token_Price_in_Cent = new_price_in_cent;
        
        // Recalculate the token price in Wei based on the new price in cents
        Token_Price_in_Wei = calculateTokenPriceInWei();

        // Emit an event to log the change in token price
        emit Setted_New_Token_Price(tx.origin,new_price_in_cent,oldPrice);

        // Return success
        return true;
    }


    // Function to allow users to buy tokens by sending tokenb to the contract
    function buyTokens(uint256 _numberOfTokensinWei) external payable returns (bool){

        // Check for zero address
        require(tx.origin != address(0), "Invalid sender address");

        // Calculate the token price in Wei
        uint256 token_price_in_eth_wei = calculateTokenPriceInWei();
        
        // Require that the sent Ether is greater than the token price
        require(msg.value > token_price_in_eth_wei , "Insufficient balance");
        
        // Require that there are enough tokens in stock
        require(Total_Token_Supply_In_Wei > _numberOfTokensinWei , "Insufficient token stock");
         
        // Transfer tokens from the contract to the buyer (tx.origin)
        _transfer(address(this), tx.origin, _numberOfTokensinWei);
        
        // Decrease the total token supply
        Total_Token_Supply_In_Wei = Total_Token_Supply_In_Wei.sub(_numberOfTokensinWei);
        
        // Emit an event to log the token purchase
        emit Buy_Token(tx.origin, _numberOfTokensinWei,Total_Token_Supply_In_Wei);
        return true;
    }
    

  
    // Function to retrieve the latest Ethereum price from the price feed.
    // The function uses the latestRoundData() function of the priceFeed,
    // extracts the price, and returns it as a uint256.
    function getLastestPrice() private view returns(uint256){
    (,int256 price,,,) = priceFeed.latestRoundData();
    uint256 priceInCents = uint256(price).div(PRICE_SCALING_FACTOR);
    return priceInCents;
    }

    //  Burns a specified amount of tokens from the contract's supply.
    function burnToken(uint256 _amountInWei) _onlyAdmin external returns(bool){
       
    // Require that there are enough tokens in stock
    require(Total_Token_Supply_In_Wei > _amountInWei , "Insufficient token stock");

    // Perform the burn operation
    _burn(address(this),  _amountInWei);
    
    // Store the old total token supply for event emission
    uint256 _oldStockInWei = Total_Token_Supply_In_Wei;
   
    // Update the total token supply after the burn
    Total_Token_Supply_In_Wei = Total_Token_Supply_In_Wei.sub(_amountInWei);

    // Emit an event to log the change in token supply
    emit Change_Token_Supply(_oldStockInWei,Total_Token_Supply_In_Wei);

     // Return success
    return true;
    }

    // Function to calculate token price in wei
    function calculateTokenPriceInWei() private view returns (uint256){
        uint256 ETHpriceInCent = getLastestPrice();
        uint256 price_in_wei = Token_Price_in_Cent.mul(ETH_SCALING_DECIMALS).div(ETHpriceInCent);
        return price_in_wei;
    }


    // Check sender is admin
    function checkIsAdmin() external view returns(bool){
        return CPTokenAdmin[tx.origin];
    }

    // Custom modifier to ensure that only existing admins can call certain functions.
    modifier _onlyAdmin(){
        require(CPTokenAdmin[tx.origin], "Only CP Token Admin call this function");
        _;
    }

    
    receive() external payable {}
    fallback() external payable {}

}
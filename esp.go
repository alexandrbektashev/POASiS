
 package main

 import (
	"fmt"
	"github.com/hyperledger/fabric-chaincode-go/shim"
	peer "github.com/hyperledger/fabric-protos-go/peer"
	"strconv"
	"encoding/json"
)

type ESPChaincode struct {
}

type ESPToken struct {
	Symbol   		string   `json:"symbol"`
	TotalSupply     uint64   `json:"totalSupply"`
	Description		string   `json:"description"`
	Creator			string   `json:"creator"`
}

const   OwnerPrefix="owner."

// Receives 4 parameters =  [0] Symbol [1] TotalSupply   [2] Description  [3] Owner
func (token *ESPChaincode) Init(stub shim.ChaincodeStubInterface) peer.Response {

	fmt.Println("Init executed")
	_, args := stub.GetFunctionAndParameters()

	if len(args) < 4 {
		return shim.Error("Failed - incorrect number of parameters!! ")
	}
	symbol := string(args[0])
	totalSupply, err := strconv.ParseUint(string(args[1]),10,64)

	if err != nil || totalSupply == 0 {
		return shim.Error("Total Supply MUST be a number > 0 !! ")
	}

	// Creator name cannot be zeo length
	if len(args[3]) == 0 {
		return errorResponse("Creator identity cannot be 0 length!!!", 3)
	}
	creator := string(args[3])

	// Create an instance of the data struct
	var data = ESPToken{Symbol: symbol, TotalSupply: totalSupply, Description: string(args[2]), Creator: creator}

	// Convert to JSON and store data in the state
	jsonData, _ := json.Marshal(data)
	stub.PutState("token", []byte(jsonData))

	// In the begining all tokens are owned by the creator of the token
	key := OwnerPrefix+creator
	fmt.Println("Key=",key)
	err=stub.PutState(key,[]byte(args[1]))
	if err != nil {
		return errorResponse(err.Error(), 4)
	}

	return shim.Success([]byte(jsonData))
}

// Invoke method
func (token *ESPChaincode) Invoke(stub shim.ChaincodeStubInterface) peer.Response {

	// Get the function name and parameters
	function, args := stub.GetFunctionAndParameters()

	fmt.Println("Invoke executed : ", function, " args=", args)

	switch {

	// Query function
	case	function == "totalSupply":
			return totalSupply(stub)
	case	function == "stateOf":
			return stateOf(stub, args)
	case	function == "transfer":
			return transfer(stub, args)
	}

	return errorResponse("Invalid function",1)
}


func totalSupply(stub shim.ChaincodeStubInterface) peer.Response {

	bytes, err := stub.GetState("token")
	if err != nil {
		return errorResponse(err.Error(), 5)
	}

	// Read the JSON and Initialize the struct
	var data  ESPToken
	_ = json.Unmarshal(bytes, &data)

	
	// Create the JSON Response with totalSupply
	return successResponse(strconv.FormatUint(data.TotalSupply,10))
}

 func stateOf(stub shim.ChaincodeStubInterface, args []string) peer.Response {
	// Check if owner id is in the arguments
	if len(args) < 1   {
		return errorResponse("Needs OwnerID!!!", 6)
	}
	OwnerID := args[0]
	bytes, err := stub.GetState(OwnerPrefix+OwnerID)
	if err != nil {
		return errorResponse(err.Error(), 7)
	}

	response := balanceJSON(OwnerID, string(bytes))

	return successResponse(response)
 }


  func transfer(stub shim.ChaincodeStubInterface, args []string) peer.Response {
	// Check if owner id is in the arguments
	if len(args) < 3   {
		return errorResponse("Needs to, from & amount!!!", 700)
	}

	from := string(args[0])
	to := string(args[1])
	amount, err := strconv.Atoi(string(args[2]))
	if err != nil {
		return errorResponse(err.Error(), 701)
	}
	if(amount <= 0){
		return errorResponse("Amount MUST be > 0!!!", 702)
	}

	// Get the Balance for from
	bytes, _ := stub.GetState(OwnerPrefix+from)
	if len(bytes) == 0 {
		// That means 0 token balance
		return errorResponse("Balance MUST be > 0!!!", 703)
	}
	fromBalance, _ := strconv.Atoi(string(bytes))
	if fromBalance < amount {
		return errorResponse("Insufficient balance to cover transfer!!!", 704)
	}
	// Reduce the tokens in from account
	fromBalance = fromBalance - amount
	
	// Get the balance in to account
	bytes, _ = stub.GetState(OwnerPrefix+to)
	toBalance := 0
	if len(bytes) > 0 {
		toBalance, _ = strconv.Atoi(string(bytes))
	}
	toBalance += amount

	// Update the balance
	bytes = []byte(strconv.FormatInt(int64(fromBalance), 10))
	err = stub.PutState(OwnerPrefix+from, bytes)

	bytes = []byte(strconv.FormatInt(int64(toBalance), 10))
	err = stub.PutState(OwnerPrefix+to, bytes)

	// Emit Transfer Event
	eventPayload := "{\"from\":\""+from+"\", \"to\":\""+to+"\",\"amount\":"+strconv.FormatInt(int64(amount),10)+"}"
	stub.SetEvent("transfer", []byte(eventPayload))
	return successResponse("Transfer Successful!!!")
  }

 func balanceJSON(OwnerID, balance string) (string) {
	 return "{\"owner\":\""+OwnerID+"\", \"balance\":"+balance+ "}"
 }


func errorResponse(err string, code  uint ) peer.Response {
	codeStr := strconv.FormatUint(uint64(code), 10)
	// errorString := "{\"error\": \"" + err +"\", \"code\":"+codeStr+" \" }"
	errorString := "{\"error\":" + err +", \"code\":"+codeStr+" \" }"
	return shim.Error(errorString)
}

func successResponse(dat string) peer.Response {
	success := "{\"response\": " + dat +", \"code\": 0 }"
	return shim.Success([]byte(success))
}

func main() {
	fmt.Println("Started....")
	err := shim.Start(new(ESPChaincode))
	if err != nil {
		fmt.Printf("Error starting chaincode: %s", err)
	}
}

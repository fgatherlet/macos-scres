CFLAGS=-framework ApplicationServices
OBJ=scres
SRC=$(OBJ).swift

default: $(OBJ)


$(OBJ): $(SRC)
	xcrun --sdk macosx swiftc $<

clean: $(OBJ)
	rm $<

.PHONY: default



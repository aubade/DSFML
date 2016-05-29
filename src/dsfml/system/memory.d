/*
DSFML - The Simple and Fast Multimedia Library for D

Copyright (c) 2013 - 2015 Jeremy DeHaan (dehaan.jeremiah@gmail.com)

This software is provided 'as-is', without any express or implied warranty.
In no event will the authors be held liable for any damages arising from the use of this software.

Permission is granted to anyone to use this software for any purpose, including commercial applications,
and to alter it and redistribute it freely, subject to the following restrictions:

1. The origin of this software must not be misrepresented; you must not claim that you wrote the original software.
If you use this software in a product, an acknowledgment in the product documentation would be appreciated but is not required.

2. Altered source versions must be plainly marked as such, and must not be misrepresented as being the original software.

3. This notice may not be removed or altered from any source distribution
*/

///A module for controlling DSFML's internal memory allocation.AARange

import core.stdc.stdlib;

import std.typecons: Rebindable;
import std.conv: emplace;

/**
*Wrapper for DSFML's internal allocation handlers.
*
*This structure can be used to override the way DSFML allocates heap memory for its internal structures.
*Any changes made should be done before creating any DSFML objects as there are no
*internal checks to see if the allocator that took care of a handle has changed.
*
*By default, DSFML uses C Malloc-based functions and does not require any of its objects to be registered with
*D's Garbage Collector. Even if you use custom allocators you will probably not need to touch this.
*
*/
struct Memory
{
	private:
	//These are technically static, but marked as nonstatic so their pointers are delegates. Saves us a phobos import.
	
	void* defaultalloc (size_t length, TypeInfo type = null) const
	{
		return malloc(length);
	}
	
	void* defaultrealloc (ref void* object, size_t newlength, TypeInfo type = null) const
	{
		if (newlength == 0) return object = null;
		else if (object is null) return allocator(newlength);
		else return object = realloc(object, newlength);
	}
	
	void defaultfree (ref void* object) const
	{
		if (object is null) return;
		
		free(object);
		object = null;
	}

	static AllocFunction allocator;
	static ReallocFunction reallocator;
	static FreeFunction freer;
	
	public:
	
	
	///Function or delegate to allocate memory
	///
	///Params:
	///  	length - the size of the memory block required in bytes.
	///     type - the typeid() of the data this memory will be used for.
	///
	///Returns: a pointer to the block of memory
	///
	alias void* delegate(size_t length, TypeInfo type = null) AllocFunction;

	///Function or delegate to reallocate memory. Its existing contents must be preserved.
	///
	///Params:
	///		object - pointer to the block of memory being reallocated. If this is null a new block
	///              must be allocated from scratch.
	///  	newlength - the new size of the memory block required in bytes. If this is zero,
	///			     	the block should be deallocated entirely and null should be returned.
	///     type - the typeid() of the data this memory will be used for.
	///
	///Returns: the new pointer to the block of memory
	///
	alias void* delegate(ref void* object, size_t newlength, TypeInfo type = null) ReallocFunction;

	///Function or delegate to allocate memory
	///
	///Params:
	///     object - the data to be freed. If this is null nothing need be done with it.
	///
	alias void delegate (ref void* object) FreeFunction;
	
	
	///Changes the allocator function DSFML uses for its internal structures.
	///
	///Params:
	///  	newAllocator - the new allocator function.
	
	static void setAllocator(AllocFunction newAllocator)
	{
		if (newAllocator is null) throw new Exception("Attempted to set null memory allocator");
		
		allocator = newAllocator;
	}	

	///Changes the allocator function DSFML uses for its internal structures.
	///
	///Params:
	///  	newAllocator - the new allocator function.
	
	static void setReallocator(ReallocFunction newReallocator)
	{
		if (newReallocator is null) throw new Exception("Attempted to set null memory reallocator");
		
		reallocator = newReallocator;
	}	

	///Changes the allocator function DSFML uses for its internal structures.
	///
	///Params:
	///  	newAllocator - the new allocator function.
	
	static void setFreer(FreeFunction newFreer)
	{
		if (newFreer is null) throw new Exception("Attempted to set null memory freer");
		
		freer = newFreer;
	}	

	///Resets all memory-related functions to their defaults
	///
	///WARNING: Don't use this while any internally-allocating DSFML structures are active.
	///Your program WILL crash.

	static void reset() {
		allocator = &Memory.init.defaultalloc;
		reallocator = &Memory.init.defaultrealloc;
		freer = &Memory.init.defaultfree;
	}
}


/**
*Creates the space to store a class object internally
*
*This is meant for internal DSFML use.
*
*/
struct StaticObject(T) if (is(T == class))
{
	//We use an array of size_t to ensure that the memory will be aligned to the arch's word size.
	//The math ensures that it will always round up. 
	private size_t[(__traits(classInstanceSize, T) + size_t.sizeof - 1) / size_t.sizeof] m_storage;
	Rebindable!T m_reference;
	
	void emplace(Args...)(auto ref Args args) if (__traits(compiles, new T(args)))
	{
		if (m_reference !is null) destroy(m_reference);
		
		m_reference = std.conv.emplace!T(cast(void[])m_storage, args);
	}
	
	@property T reference ()
	{
		return m_reference;
	} 
	
	~this()
	{
		if (m_reference !is null) destroy(m_reference);
		m_reference = null;
	}
}
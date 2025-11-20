"""Write-focused helpers for Firestore mutations in the game service.

These modules contain stateless helpers that perform write-only operations
against Firestore using a provided writer (transaction or batch). They do not
own reads or HTTP-aware exceptions; reads are centralized in repositories and
HTTP mapping happens at the use-case/application boundary.
"""
